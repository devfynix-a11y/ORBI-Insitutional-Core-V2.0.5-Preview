# Load Tests

This folder contains starter load-testing assets for ORBI production readiness work.

## k6 Baseline Probe

File:

- `k6/readiness-and-metrics.js`

Purpose:

- validate basic health endpoint behavior under concurrent load
- exercise readiness behavior
- verify the operational Prometheus endpoint when an admin monitor API key is available

## Example Usage

```bash
k6 run loadtests/k6/readiness-and-metrics.js
```

With parameters:

```bash
ORBI_BASE_URL=http://localhost:3000 \
ORBI_MONITOR_API_KEY=replace_me \
ORBI_VUS=50 \
ORBI_TEST_DURATION=5m \
k6 run loadtests/k6/readiness-and-metrics.js
```

`ORBI_MONITOR_API_KEY` is an internal monitor token used only for protected monitor endpoints. It is intentionally separate from tenant-facing `x-api-key` credentials.

## Next Tests To Add

- authenticated login throughput
- payment preview flow
- provider webhook burst simulation
- settlement backlog pressure test
- offline gateway confirmation spikes
