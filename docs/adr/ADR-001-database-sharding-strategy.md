# ADR-001: Database Sharding Strategy

Status: Accepted

Date: 2026-04-18

## Context

ORBI currently operates from a PostgreSQL/Supabase core with financial ledger, settlement, provider, organization, and consumer data in one logical database. This is correct for the current stage because it preserves transactional integrity, but production-scale institutional traffic will eventually need tenant-aware distribution.

## Decision

Use Citus for distributed PostgreSQL with `institution_id` as the shard key when traffic or data volume exceeds the single-primary database envelope.

## Alternatives

- Vitess.
- Native PostgreSQL partitioning only.
- Manual application-level sharding.

## Rationale

Citus keeps PostgreSQL semantics and tooling while adding transparent distribution and tenant-aware scaling. `institution_id` gives a stable data-locality boundary for institutional workloads and avoids splitting one institution's financial history across unrelated shards.

## Consequences

- Tables that participate in institution-scoped joins need an `institution_id` or equivalent tenant key before distribution.
- Reference tables such as providers and currencies should be replicated as Citus reference tables.
- Cross-tenant analytics should move to read models or warehouse pipelines instead of OLTP joins.
