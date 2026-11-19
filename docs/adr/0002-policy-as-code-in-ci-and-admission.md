# ADR 0002: Enforce policy both in CI and at admission

- Status: accepted
- Date: 2026-11-19

## Context

CI checks give fast feedback but can be bypassed with a manual `kubectl apply`. Admission control cannot be bypassed but gives late feedback, during a deploy.

## Decision

Keep two copies of the workload rules:

- `policies/kubernetes/*.rego`, run by conftest in CI, with unit tests (`conftest verify`).
- `platform/gatekeeper/templates/*.yaml`, enforced by OPA Gatekeeper at admission.

Pod Security Admission `restricted` runs as a baseline that needs no extra component.

## Consequences

- Developers see violations in the pull request, not at deploy time.
- The cluster still rejects anything that skipped CI.
- The two copies can drift. Mitigation: both are reviewed in the same PR; generating one from the other is on the roadmap.
