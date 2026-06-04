import assert from 'node:assert/strict';
import test from 'node:test';

import { ApiGatewaySecurityService } from '../backend/security/ApiGatewaySecurityService.js';
import {
  buildRedactedPayloadFeatures,
  DeterministicSecurityScoringAdapter,
  HttpSecurityScoringAdapter,
} from '../backend/security/SecurityScoringAdapter.js';

test('api gateway classifies critical route groups', () => {
  const gateway = new ApiGatewaySecurityService(new DeterministicSecurityScoringAdapter());

  assert.equal(gateway.classifyForTest('/auth/login', 'POST').group, 'auth');
  assert.equal(gateway.classifyForTest('/transactions/settle', 'POST').group, 'financial');
  assert.equal(gateway.classifyForTest('/admin/b2b/organization-limits', 'POST').group, 'admin');
  assert.equal(gateway.classifyForTest('/webhooks/gateway/provider-1', 'POST').group, 'provider_webhook');
  assert.equal(gateway.classifyForTest('/operational-metrics/snapshot', 'POST').group, 'monitor_internal');
});

test('security scoring payload features redact secrets and OTPs', () => {
  const req = {
    body: {
      email: 'amina@example.com',
      password: 'should-not-leak',
      otp: '123456',
      amount: 12000,
    },
    query: {
      search: 'wallet',
      token: 'hidden',
    },
  } as any;

  const features = buildRedactedPayloadFeatures(req);

  assert.deepEqual(features.bodyKeys, ['email', 'amount']);
  assert.deepEqual(features.queryKeys, ['search']);
  assert.equal(features.sensitiveBodyKeyCount, 2);
  assert.equal((features.selected as any).password, undefined);
  assert.equal((features.selected as any).otp, undefined);
  assert.equal((features.selected as any).token, undefined);
});

test('deterministic scoring escalates high velocity sensitive operations', async () => {
  const adapter = new DeterministicSecurityScoringAdapter();
  const result = await adapter.score({
    route: '/transactions/settle',
    method: 'POST',
    routeClass: 'FINANCIAL_COMMIT',
    actorId: 'user-1',
    ipHash: 'ip',
    deviceHash: null,
    appId: 'ORBI_MOBILE_V2026',
    velocityScore: 70,
    velocityCount: 50,
    redactedPayloadFeatures: {},
  });

  assert.equal(result.action, 'BLOCK');
  assert.equal(result.modelVersion, 'orbi-deterministic-gateway-v1');
  assert.ok(result.signals.some((signal) => signal.type === 'MISSING_DEVICE_IDENTITY'));
});

test('http scoring adapter falls back when python scorer is unavailable', async () => {
  const adapter = new HttpSecurityScoringAdapter(
    'http://127.0.0.1:1',
    100,
    new DeterministicSecurityScoringAdapter(),
  );

  const result = await adapter.score({
    route: '/admin/config/bootstrap',
    method: 'POST',
    routeClass: 'CONFIG_COMMIT',
    actorId: 'staff-1',
    ipHash: 'ip',
    deviceHash: 'device',
    appId: 'ORBI_NODE_PORTAL_V2026',
    velocityScore: 0,
    velocityCount: 1,
    redactedPayloadFeatures: {},
  });

  assert.equal(result.modelVersion, 'orbi-deterministic-gateway-v1');
  assert.ok(result.signals.some((signal) => signal.type === 'AI_SCORER_FALLBACK'));
});
