# ADR-002: Event Sourcing Implementation

Status: Accepted

Date: 2026-04-18

## Context

Financial transactions, ledger entries, settlement lifecycle changes, and provider webhook applications need replayability and auditability. User profiles and low-risk preference records do not need the same operational complexity.

## Decision

Implement event sourcing for transaction ledger and settlement history only. Do not event-source user profiles by default.

## Alternatives

- Full event sourcing for every domain object.
- No event sourcing, only CRUD tables plus audit logs.

## Rationale

Ledger and settlement domains require strong audit trails, deterministic replay, and repair visibility. User profiles have lower compliance value and are better served by conventional state tables plus audit events.

## Consequences

- Transaction/settlement state transitions should append immutable events before or alongside projections.
- Read models may be rebuilt from transaction events when needed.
- Profile and settings changes remain simpler CRUD flows with audit logging.
