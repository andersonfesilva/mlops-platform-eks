# ADR 0003: KServe in RawDeployment mode with the Hugging Face (vLLM) runtime

- Status: accepted
- Date: 2026-11-19

## Context

The platform needs an inference server with an OpenAI-compatible API, GPU scheduling and a standard Kubernetes resource model. KServe Serverless mode adds Knative and a service mesh, which increases the attack surface and operational load for a single model.

## Decision

Use KServe `InferenceService` in **RawDeployment** mode with the Hugging Face runtime, which serves models with vLLM and exposes `/openai/v1`. Schedule it on a tainted GPU node group (spot, scales from 0).

## Consequences

- Plain Deployment + Service: standard NetworkPolicies and Gatekeeper rules apply without mesh-specific configuration.
- No scale-to-zero at the pod level; cost control comes from the node group bounds instead.
- Any OpenAI-compatible client works, so the RAG API is not tied to KServe.
