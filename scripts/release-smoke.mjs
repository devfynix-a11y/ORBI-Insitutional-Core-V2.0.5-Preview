const args = process.argv.slice(2);

if (args.includes('--help')) {
  console.log(`
ORBI release smoke test

Environment variables:
  ORBI_BASE_URL              Base URL to test, e.g. https://orbi.example.com
  ORBI_MONITOR_API_KEY       internal monitor token for protected monitor endpoints
  ORBI_EXPECT_BROKER_HEALTH  true|false, default false

Example:
  ORBI_BASE_URL=https://orbi.example.com ORBI_MONITOR_API_KEY=secret node scripts/release-smoke.mjs
`.trim());
  process.exit(0);
}

const baseUrl = (process.env.ORBI_BASE_URL || '').trim().replace(/\/+$/, '');
const monitorApiKey = (process.env.ORBI_MONITOR_API_KEY || '').trim();
const expectBrokerHealth = String(process.env.ORBI_EXPECT_BROKER_HEALTH || 'false').toLowerCase() === 'true';

if (!baseUrl) {
  console.error('Missing ORBI_BASE_URL');
  process.exit(1);
}

const checks = [];

const addCheck = (name, passed, details) => {
  checks.push({ name, passed, details });
};

const requestJson = async (path, options = {}) => {
  const response = await fetch(`${baseUrl}${path}`, options);
  const contentType = response.headers.get('content-type') || '';
  const isJson = contentType.includes('application/json');
  const body = isJson ? await response.json() : await response.text();
  return { response, body };
};

const monitorHeaders = monitorApiKey ? { Authorization: `Bearer ${monitorApiKey}` } : {};

try {
  const health = await requestJson('/health');
  addCheck(
    'health',
    health.response.status === 200 && health.body?.status === 'ONLINE',
    { statusCode: health.response.status, body: health.body },
  );

  const ready = await requestJson('/ready');
  addCheck(
    'ready',
    ready.response.status === 200 && ready.body?.status === 'READY',
    { statusCode: ready.response.status, body: ready.body },
  );

  const deep = await requestJson('/health/deep');
  addCheck(
    'health_deep',
    deep.response.status === 200 && deep.body?.status !== 'CRITICAL',
    { statusCode: deep.response.status, body: deep.body },
  );

  if (monitorApiKey) {
    const operational = await requestJson('/api/admin/monitor/operational-health', {
      headers: monitorHeaders,
    });
    addCheck(
      'operational_health',
      operational.response.status === 200 && operational.body?.success === true && operational.body?.data?.status !== 'CRITICAL',
      { statusCode: operational.response.status, body: operational.body },
    );

    const metrics = await fetch(`${baseUrl}/api/admin/monitor/operational-metrics/prometheus`, {
      headers: monitorHeaders,
    });
    const metricsBody = await metrics.text();
    addCheck(
      'prometheus_metrics',
      metrics.status === 200 && metricsBody.includes('orbi_operational_status'),
      { statusCode: metrics.status, excerpt: metricsBody.slice(0, 400) },
    );
  } else {
    addCheck('operational_health', false, { reason: 'ORBI_MONITOR_API_KEY not set' });
    addCheck('prometheus_metrics', false, { reason: 'ORBI_MONITOR_API_KEY not set' });
  }

  if (expectBrokerHealth) {
    const broker = await requestJson('/api/broker/health');
    addCheck(
      'broker_health',
      broker.response.status === 200 && broker.body?.status === 'HEALTHY',
      { statusCode: broker.response.status, body: broker.body },
    );
  }
} catch (error) {
  console.error('Smoke test failed before completion:', error);
  process.exit(1);
}

const failed = checks.filter((check) => !check.passed);

for (const check of checks) {
  const state = check.passed ? 'PASS' : 'FAIL';
  console.log(`${state} ${check.name}`);
}

if (failed.length > 0) {
  console.error('\nFailed checks:');
  for (const check of failed) {
    console.error(`- ${check.name}: ${JSON.stringify(check.details)}`);
  }
  process.exit(1);
}

console.log('\nAll smoke checks passed.');
