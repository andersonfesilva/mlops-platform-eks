# Architecture

## Request flow

```mermaid
sequenceDiagram
    autonumber
    participant C as Client
    participant A as rag-api
    participant G as Guardrails
    participant R as Retriever (BM25)
    participant L as LLM (KServe / vLLM)

    C->>A: POST /v1/ask {question}
    A->>G: check_input()
    alt injection, credential or invalid size
        G-->>A: blocked
        A-->>C: 400 + reason (model never called)
    end
    A->>R: search(redacted question)
    alt no relevant passage
        A-->>C: 200 "I don't know" (model never called)
    end
    A->>L: system prompt + numbered <context> + question
    L-->>A: answer
    A->>G: check_output(answer, n_sources)
    alt credential, no citation or invalid citation
        A-->>C: 422 + reason
    end
    A-->>C: 200 answer + cited sources + redactions
```

## Infrastructure dependency graph

Terragrunt stacks under `infra/live/dev` are applied in this order:

```mermaid
flowchart LR
    vpc[vpc] --> eks[eks] --> irsa[irsa-rag-api]
```

| Stack | Creates |
| --- | --- |
| `vpc` | VPC across 2-3 AZs, private + public subnets, NAT, flow logs, locked default SG |
| `eks` | EKS cluster, KMS key for Secrets, add-ons (VPC CNI with network policy, CoreDNS, kube-proxy, Pod Identity agent), `system` node group and a GPU `inference` node group (spot, scales from 0) |
| `irsa-rag-api` | IAM role assumable only by `system:serviceaccount:rag:rag-api`, read-only on one S3 prefix |

## Policy enforcement points

The same rules are enforced twice, on purpose:

1. **In CI (shift-left)**: `conftest` runs `policies/kubernetes` against the manifests; Checkov and Trivy scan Terraform, Kubernetes and the Dockerfile. A bad change fails the pull request.
2. **At admission (runtime)**: Pod Security Admission (`restricted`) and Gatekeeper constraints reject anything that bypassed CI, such as a manual `kubectl apply`.

## Design decisions

See [docs/adr](adr/).
