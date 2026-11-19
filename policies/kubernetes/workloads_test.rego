package main

import rego.v1

good_deployment := {
	"kind": "Deployment",
	"metadata": {"name": "api"},
	"spec": {"template": {"spec": {
		"securityContext": {"runAsNonRoot": true},
		"containers": [{
			"name": "api",
			"image": "111111111111.dkr.ecr.us-east-1.amazonaws.com/api:1.0.0",
			"securityContext": {
				"allowPrivilegeEscalation": false,
				"readOnlyRootFilesystem": true,
				"capabilities": {"drop": ["ALL"]},
			},
			"resources": {"limits": {"memory": "256Mi"}},
		}],
	}}},
}

test_good_deployment_passes if {
	count(deny) == 0 with input as good_deployment
}

test_privileged_denied if {
	bad := json.patch(good_deployment, [{"op": "add", "path": "/spec/template/spec/containers/0/securityContext/privileged", "value": true}])
	count(deny) > 0 with input as bad
}

test_latest_tag_denied if {
	bad := json.patch(good_deployment, [{"op": "replace", "path": "/spec/template/spec/containers/0/image", "value": "nginx:latest"}])
	some msg in deny with input as bad
	contains(msg, ":latest")
}

test_untagged_image_denied if {
	bad := json.patch(good_deployment, [{"op": "replace", "path": "/spec/template/spec/containers/0/image", "value": "nginx"}])
	some msg in deny with input as bad
	contains(msg, "no tag or digest")
}

test_missing_memory_limit_denied if {
	bad := json.patch(good_deployment, [{"op": "remove", "path": "/spec/template/spec/containers/0/resources/limits"}])
	some msg in deny with input as bad
	contains(msg, "memory limit")
}

test_root_pod_denied if {
	bad := json.patch(good_deployment, [{"op": "remove", "path": "/spec/template/spec/securityContext"}])
	some msg in deny with input as bad
	contains(msg, "runAsNonRoot")
}

test_public_load_balancer_denied if {
	svc := {"kind": "Service", "metadata": {"name": "web"}, "spec": {"type": "LoadBalancer"}}
	count(deny) == 1 with input as svc
}

test_internal_load_balancer_allowed if {
	svc := {
		"kind": "Service",
		"metadata": {"name": "web", "annotations": {"service.beta.kubernetes.io/aws-load-balancer-scheme": "internal"}},
		"spec": {"type": "LoadBalancer"},
	}
	count(deny) == 0 with input as svc
}
