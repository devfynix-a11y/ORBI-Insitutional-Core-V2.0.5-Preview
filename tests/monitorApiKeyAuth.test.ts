import assert from 'node:assert/strict';
import test from 'node:test';

import { authenticateMonitorApiKey } from '../backend/middleware/monitorApiKeyAuth.js';

const createReq = (headers: Record<string, string> = {}) => ({
  headers,
}) as any;

const createRes = () => {
  const res: any = {
    statusCode: 200,
    body: null,
    status(code: number) {
      res.statusCode = code;
      return res;
    },
    json(payload: any) {
      res.body = payload;
      return res;
    },
  };
  return res;
};

test('authenticateMonitorApiKey accepts bearer token that matches ORBI_MONITOR_API_KEY', async () => {
  const previous = process.env.ORBI_MONITOR_API_KEY;
  process.env.ORBI_MONITOR_API_KEY = 'monitor-secret';

  const req = createReq({ authorization: 'Bearer monitor-secret' });
  const res = createRes();
  let nextCalled = false;

  authenticateMonitorApiKey(req, res, () => {
    nextCalled = true;
  });

  assert.equal(nextCalled, true);
  assert.equal(req.monitorAccess, true);

  if (previous === undefined) delete process.env.ORBI_MONITOR_API_KEY;
  else process.env.ORBI_MONITOR_API_KEY = previous;
});

test('authenticateMonitorApiKey accepts x-orbi-monitor-key header', async () => {
  const previous = process.env.ORBI_MONITOR_API_KEY;
  process.env.ORBI_MONITOR_API_KEY = 'monitor-secret';

  const req = createReq({ 'x-orbi-monitor-key': 'monitor-secret' });
  const res = createRes();
  let nextCalled = false;

  authenticateMonitorApiKey(req, res, () => {
    nextCalled = true;
  });

  assert.equal(nextCalled, true);
  assert.equal(req.monitorAccess, true);

  if (previous === undefined) delete process.env.ORBI_MONITOR_API_KEY;
  else process.env.ORBI_MONITOR_API_KEY = previous;
});

test('authenticateMonitorApiKey rejects tenant api keys on monitor routes', async () => {
  const previous = process.env.ORBI_MONITOR_API_KEY;
  process.env.ORBI_MONITOR_API_KEY = 'monitor-secret';

  const req = createReq({ 'x-api-key': 'sk_live_tenant_key' });
  const res = createRes();
  let nextCalled = false;

  authenticateMonitorApiKey(req, res, () => {
    nextCalled = true;
  });

  assert.equal(nextCalled, false);
  assert.equal(res.statusCode, 401);
  assert.equal(res.body.error, 'Missing monitor credentials');

  if (previous === undefined) delete process.env.ORBI_MONITOR_API_KEY;
  else process.env.ORBI_MONITOR_API_KEY = previous;
});

test('authenticateMonitorApiKey reports configuration error when ORBI_MONITOR_API_KEY is unset', async () => {
  const previous = process.env.ORBI_MONITOR_API_KEY;
  delete process.env.ORBI_MONITOR_API_KEY;

  const req = createReq({ authorization: 'Bearer anything' });
  const res = createRes();
  let nextCalled = false;

  authenticateMonitorApiKey(req, res, () => {
    nextCalled = true;
  });

  assert.equal(nextCalled, false);
  assert.equal(res.statusCode, 503);
  assert.equal(res.body.error, 'MONITOR_AUTH_NOT_CONFIGURED');

  if (previous !== undefined) process.env.ORBI_MONITOR_API_KEY = previous;
});
