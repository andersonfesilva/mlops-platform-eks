# Shift-left checks for Kubernetes manifests, run in CI with conftest before
# anything reaches the cluster. They mirror the Gatekeeper constraints in
# platform/gatekeeper so a bad manifest fails the PR instead of the deploy.
package main

import rego.v1

workload_kinds := {"Deployment", "StatefulSet", "DaemonSet", "Job"}

pod_spec := input.spec.template.spec if workload_kinds[input.kind]

pod_spec := input.spec.jobTemplate.spec.template.spec if input.kind == "CronJob"

containers contains c if some c in pod_spec.containers

containers contains c if some c in pod_spec.initContainers

deny contains msg if {
	some c in containers
	c.securityContext.privileged == true
	msg := sprintf("%s/%s: container %q must not be privileged", [input.kind, input.metadata.name, c.name])
}

deny contains msg if {
	some c in containers
	not c.securityContext.allowPrivilegeEscalation == false
	msg := sprintf("%s/%s: container %q must set allowPrivilegeEscalation=false", [input.kind, input.metadata.name, c.name])
}

deny contains msg if {
	some c in containers
	not "ALL" in c.securityContext.capabilities.drop
	msg := sprintf("%s/%s: container %q must drop ALL capabilities", [input.kind, input.metadata.name, c.name])
}

deny contains msg if {
	some c in containers
	not c.securityContext.readOnlyRootFilesystem == true
	msg := sprintf("%s/%s: container %q must use a read-only root filesystem", [input.kind, input.metadata.name, c.name])
}

deny contains msg if {
	some c in containers
	not c.resources.limits.memory
	msg := sprintf("%s/%s: container %q must set a memory limit", [input.kind, input.metadata.name, c.name])
}

deny contains msg if {
	some c in containers
	endswith(c.image, ":latest")
	msg := sprintf("%s/%s: container %q uses the mutable tag :latest", [input.kind, input.metadata.name, c.name])
}

deny contains msg if {
	some c in containers
	not contains(c.image, ":")
	not contains(c.image, "@sha256:")
	msg := sprintf("%s/%s: container %q image has no tag or digest", [input.kind, input.metadata.name, c.name])
}

deny contains msg if {
	pod_spec
	not pod_spec.securityContext.runAsNonRoot == true
	msg := sprintf("%s/%s: pod must set securityContext.runAsNonRoot=true", [input.kind, input.metadata.name])
}

deny contains msg if {
	pod_spec.hostNetwork == true
	msg := sprintf("%s/%s: pod must not use hostNetwork", [input.kind, input.metadata.name])
}

# A Service of type LoadBalancer must be internal unless explicitly reviewed.
deny contains msg if {
	input.kind == "Service"
	input.spec.type == "LoadBalancer"
	not input.metadata.annotations["service.beta.kubernetes.io/aws-load-balancer-scheme"] == "internal"
	msg := sprintf("Service/%s: LoadBalancer must be internal (aws-load-balancer-scheme: internal)", [input.metadata.name])
}
