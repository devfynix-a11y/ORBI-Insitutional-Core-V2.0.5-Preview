# ADR-003: Provider Resilience Pattern

Status: Accepted

Date: 2026-04-18

## Context

External providers can fail, slow down, throttle, or return inconsistent errors. Provider failures must not cascade into internal ledger, settlement, or unrelated provider flows.

## Decision

Use circuit breakers, provider-level bulkheads, and retry with exponential backoff for provider calls.

## Rationale

Circuit breakers stop repeated calls into an unhealthy provider. Bulkheads cap concurrent work per provider so one slow provider does not consume all backend capacity. Retry with backoff handles transient network and provider faults without creating retry storms.

## Consequences

- Provider calls should flow through the shared provider retry policy.
- Circuit and bulkhead limits are environment configurable.
- Provider metrics should track request volume, latency, error rate, and SLA violations for ranking and routing.
