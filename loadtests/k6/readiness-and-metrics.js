import http from 'k6/http';
import { check, sleep } from 'k6';

const baseUrl = __ENV.ORBI_BASE_URL || 'http://localhost:3000';
const adminApiKey = __ENV.ORBI_MONITOR_API_KEY || '';
const duration = __ENV.ORBI_TEST_DURATION || '2m';

export const options = {
  vus: Number(__ENV.ORBI_VUS || 20),
  duration,
  thresholds: {
    http_req_failed: ['rate<0.01'],
    http_req_duration: ['p(95)<750'],
  },
};

const authHeaders = adminApiKey
  ? {
      Authorization: `Bearer ${adminApiKey}`,
    }
  : {};

export default function () {
  const health = http.get(`${baseUrl}/health`);
  check(health, {
    'health returns 200': (r) => r.status === 200,
  });

  const ready = http.get(`${baseUrl}/ready`);
  check(ready, {
    'ready returns 200 or 503': (r) => r.status === 200 || r.status === 503,
  });

  if (adminApiKey) {
    const metrics = http.get(`${baseUrl}/api/admin/monitor/operational-metrics/prometheus`, {
      headers: authHeaders,
    });

    check(metrics, {
      'prometheus endpoint returns 200': (r) => r.status === 200,
      'prometheus endpoint exposes orbi metrics': (r) => r.body.includes('orbi_operational_status'),
    });
  }

  sleep(1);
}
