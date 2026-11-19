# Runbook: Instance Metadata Service (IMDS) hardening

## Why it matters

Pods that can reach the EC2 instance metadata service at 169.254.169.254 can read the
temporary credentials of the node IAM role. A server-side request forgery (SSRF) bug in any
application on the node then becomes a credential theft.

## Required configuration

Require IMDSv2 on every node (http_tokens = required) and set the response hop limit to 1,
so containers cannot reach the metadata service through the node network namespace.
Give workloads their own identity with IRSA or EKS Pod Identity instead of relying on the
node role.

## Detection

GuardDuty raises UnauthorizedAccess:IAMUser/InstanceCredentialExfiltration when node
credentials are used from outside AWS. Route the finding to Security Hub and page the
on-call engineer.
