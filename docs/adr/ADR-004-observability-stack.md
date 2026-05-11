# ADR-004: Observability Stack

Status: Accepted

Date: 2026-04-18

## Context

ORBI needs request tracing, structured logs, metrics, dashboards, and alerting for financial operations. The stack should be portable and avoid early lock-in.

## Decision

Use OpenTelemetry, Prometheus, Grafana, Tempo, and Loki as the observability baseline.

## Alternatives

- Datadog.
- New Relic.
- Dynatrace.

## Rationale

The selected stack is CNCF-aligned, vendor neutral, widely supported, and cost-effective. It also fits the existing Prometheus metric rendering and structured logging direction.

## Consequences

- Services should emit trace IDs and structured logs consistently.
- `/health/deep` and Prometheus metrics should feed dashboards and alerts.
- Hosted observability products can still be adopted later by exporting OpenTelemetry data.
