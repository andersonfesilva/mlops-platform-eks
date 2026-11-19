# ADR 0001: Terragrunt with thin wrappers over community modules

- Status: accepted
- Date: 2026-11-19

## Context

VPC and EKS have hundreds of options. Writing them from scratch adds risk without adding value; using the community modules directly spreads security-relevant defaults across every environment.

## Decision

Wrap `terraform-aws-modules/vpc` and `terraform-aws-modules/eks` in thin local modules that **hard-code the security baseline** (private endpoint, IMDSv2, KMS, flow logs, access entries) and expose only the inputs an environment should change. Terragrunt handles remote state, provider generation and the dependency graph between stacks.

## Consequences

- Security defaults live in one place and are reviewed once.
- Input validation rejects unsafe values (for example `0.0.0.0/0` on the API endpoint) at plan time.
- Upgrading a community module is a single version bump, tested in `dev` first.
