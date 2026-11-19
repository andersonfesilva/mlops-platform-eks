# Threat model

Scope: the RAG API, the LLM inference service and the EKS cluster that hosts them.
Method: STRIDE-style, focused on threats specific to an LLM workload on Kubernetes.

## Assets

| Asset | Why it matters |
| --- | --- |
| Node IAM credentials | Access to everything the node role can do in the account |
| RAG corpus in S3 | Internal runbooks; confidentiality |
| System prompt and guardrail logic | Knowing them makes bypasses easier |
| Model endpoint | GPU cost; abuse turns into a bill |
| Audit logs | Evidence for incident response |

## Threats and mitigations

| # | Threat | Mitigation | Residual risk |
| --- | --- | --- | --- |
| T1 | **Direct prompt injection** ("ignore previous instructions...") | Input guard blocks known patterns before retrieval or the model; system prompt marks context as data | Rephrased attacks can pass the regex. Mitigated by T3 and the output guard. Roadmap: evaluation suite |
| T2 | **Indirect prompt injection** through a poisoned document in the corpus | Corpus is read-only to the service (IRSA, one prefix); context wrapped in `<context>` and labelled as data; output must cite real passages | Someone with write access to the bucket can still poison answers. Roadmap: corpus signing and review |
| T3 | **Ungrounded or hallucinated answers** presented as fact | Output guard requires at least one valid citation; otherwise `422`. No context means refusal without a model call | The model can cite a passage and still misstate it |
| T4 | **Credential or PII leakage** in questions or answers | Credentials in input are rejected; credentials in output block the answer; e-mail, CPF and Luhn-valid cards are redacted; question text is never logged | Unknown secret formats are not detected |
| T5 | **SSRF to instance metadata** to steal node credentials | IMDSv2 required, hop limit 1; metadata IP excluded from egress NetworkPolicies; workloads use IRSA | None known for pods on the network path |
| T6 | **Lateral movement** inside the cluster | Default-deny NetworkPolicies; only `rag-api -> llm:8080`; PSA `restricted`; Gatekeeper blocks privileged pods and requires `drop: [ALL]` | Policies depend on the VPC CNI network policy agent being healthy |
| T7 | **Malicious or vulnerable images** | Gatekeeper: ECR-only images in `rag`, no `:latest`; Trivy image scan in CI | `inference` still pulls from Docker Hub. Roadmap: mirror + cosign verification |
| T8 | **Cluster API exposure** | Private endpoint by default; public access requires an explicit allowlist and rejects `0.0.0.0/0`; access entries with named roles only | Allowlisted CIDRs must be maintained |
| T9 | **Denial of wallet** (GPU abuse) | GPU node group scales from 0 with a hard max; spot capacity; question length limit | No per-client rate limiting yet. Roadmap: API gateway with quotas |
| T10 | **Repudiation** | Structured audit log per request (decision, reason, sources, latency); EKS audit logs to CloudWatch | Logs are not yet shipped to an immutable store |
