# ORBI Production Banking Scale Plan

## Purpose

This document turns the current production-readiness suggestions into a concrete delivery plan for evolving ORBI Institutional Core into a production banking-scale platform.

It is intentionally split into:

- what must be done before broad live financial scale
- what can be delivered in parallel
- what should be deferred until operational evidence supports the extra complexity

## Current Assessment

ORBI already has a strong core foundation:

- API gateway and route modularity
- centralized ledger and settlement logic
- Redis-backed throttling and replay protection
- structured logging
- readiness and deep health probes
- operational metrics generation
- audit, reconciliation, and KMS boundaries

ORBI is not yet fully production-banking-scale ready because the platform still needs stronger:

- release automation
- observability and alerting
- load and recovery validation
- disaster recovery rehearsal
- environment governance
- workload separation outside the ledger path

## Delivery Principles

1. Protect the ledger path first.
2. Prefer platform hardening before architectural fragmentation.
3. Add operational evidence, not just documentation.
4. Separate non-ledger workloads before touching financial posting design.
5. Introduce new complexity only when it reduces measurable operational risk.

## Workstreams

### Workstream 1: Release Safety

Goal:
Make every change pass through repeatable validation before production deployment.

Deliverables:

- repository CI workflow for install, lint, test, and build
- release checklist tied to staging and production promotion
- smoke validation after deployment
- rollback procedure exercised against the current deployment target

Acceptance criteria:

- every pull request runs automated build validation
- mainline deployments are blocked when lint, tests, or build fail
- every release has a documented rollback path

### Workstream 2: Observability And Alerting

Goal:
Ensure the team can detect, triage, and act on financial or platform degradation early.

Deliverables:

- Prometheus scrape configuration aligned to the real operational metrics endpoint
- alert rules for readiness, queue backlog, webhook failures, reconciliation drift, and Redis or DB degradation
- dashboards for:
  - platform health
  - settlement backlog
  - webhook outcomes
  - reconciliation mismatches
  - wallet drift
- on-call runbook mapping alerts to actions

Acceptance criteria:

- alerts fire from real backend metrics
- operations can identify whether an issue is gateway, Redis, database, worker, provider, or settlement related within minutes

### Workstream 3: Load, Capacity, And Resilience Validation

Goal:
Prove the system can tolerate expected and peak traffic before broad launch.

Deliverables:

- k6 load-test suite for health, readiness, auth, and payment-adjacent flows
- baseline load profile for expected launch traffic
- 5x and 10x traffic test targets
- documented bottlenecks and remediation actions
- staging failure drills for:
  - Redis unavailability
  - provider timeout spikes
  - settlement backlog growth
  - webhook replay bursts

Acceptance criteria:

- load tests are executable by the team without manual rewiring
- staging performance thresholds are known
- failure drills are documented with outcomes

### Workstream 4: Disaster Recovery And Security Operations

Goal:
Move from documented intent to rehearsed operational recovery.

Deliverables:

- disaster recovery runbook
- KMS custody and recovery checklist
- backup restore validation procedure
- incident classifications for:
  - ledger drift
  - settlement stall
  - provider callback failure
  - key rotation or recovery failure
- evidence retention process for audit and forensics

Acceptance criteria:

- restore steps are testable and rehearsed
- KMS recovery assumptions are verified
- every critical incident type has a first-response checklist

### Workstream 5: Environment Governance

Goal:
Reduce release and configuration risk across environments.

Deliverables:

- strict development, staging, and production environment separation
- production-secret handling standards
- approval workflow for financial-impacting changes
- environment parity checklist for routing, webhook secrets, Redis TLS, mTLS, and gateway configuration

Acceptance criteria:

- production-only secrets are never required for local development
- staging can validate production-like behavior
- configuration drift is auditable

### Workstream 6: Service Extraction Roadmap

Goal:
Improve scale and fault isolation without destabilizing the financial core.

Deliverables:

- isolate operationally safe services first:
  - notifications
  - provider callback processing
  - KYC and document processing
  - reconciliation workers
  - reporting and analytics
- preserve the current ledger and settlement authority as the core transactional boundary
- define interfaces and SLOs before extracting workloads

Acceptance criteria:

- non-ledger services can fail without corrupting core financial state
- service extraction decisions are driven by operational evidence rather than fashion

## Phased Plan

### Phase 0: Immediate Hardening

Priority: P0

Deliver now:

- CI workflow
- corrected Prometheus scrape configuration
- production alert rules
- disaster recovery runbook
- load-test scaffolding

Outcome:
Release safety and monitoring become materially better without changing core money movement logic.

### Phase 1: Launch Readiness

Priority: P0

Deliver next:

- staging-to-production promotion gate
- smoke tests in deployment pipeline
- restore drill in staging or production-like environment
- on-call playbooks for alerts
- baseline and peak load test execution

Outcome:
The team can launch with a controlled operational posture and known failure handling paths.

### Phase 2: Controlled Scale Expansion

Priority: P1

Deliver after launch stabilization:

- stronger dashboards and SLOs
- worker isolation for non-ledger tasks
- provider callback processing isolation
- analytics offload from the transactional database

Outcome:
Higher traffic can be supported without overloading the financial core or the primary database.

### Phase 3: Banking-Grade Maturity

Priority: P2

Deliver when scale justifies it:

- service mesh or equivalent internal traffic policy
- GitOps or stronger deployment governance
- advanced chaos testing
- deeper data architecture changes such as read-model offload or sharding

Outcome:
The platform becomes more resilient and governable at institutional scale, but only after the simpler controls are proven.

## What We Should Build First

The first implementation batch should focus on the highest leverage gaps:

1. CI workflow
2. Prometheus alerting aligned to real backend metrics
3. load-test starter suite
4. disaster recovery runbook

These four items improve launch safety immediately and do not require risky ledger refactors.

## Exit Criteria For "Production Banking Scale Ready"

ORBI should only be described as production banking-scale ready when all of the following are true:

- automated CI gates are enforced
- staging and production deployment flows are documented and repeatable
- alerts exist for platform and financial degradation
- load tests have been run and reviewed at expected and peak traffic
- backup restore has been tested successfully
- KMS recovery assumptions are verified
- on-call responders have operational runbooks
- non-ledger failure does not compromise ledger integrity

## Progress Tracking

Recommended status model:

- `NOT_STARTED`
- `IN_PROGRESS`
- `BLOCKED`
- `DONE`

Recommended weekly review fields:

- owner
- target date
- current status
- risk level
- dependency
- evidence link

## Immediate Build Scope In This Iteration

This iteration will deliver:

- the concrete production scale plan
- CI scaffolding
- Prometheus alert rules and corrected scrape target
- load-test starter assets
- a disaster recovery runbook
- a backup restore drill procedure
- a drill evidence generator

These changes do not make ORBI fully production banking-scale ready by themselves, but they are the correct first build step toward that target.
