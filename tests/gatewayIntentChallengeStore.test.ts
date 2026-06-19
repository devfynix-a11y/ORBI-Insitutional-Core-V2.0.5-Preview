import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import test from 'node:test';

const migration = readFileSync(
  new URL('../database/migrations/20260618_gateway_intent_challenge_store.sql', import.meta.url),
  'utf8',
);
const service = readFileSync(
  new URL('../backend/payments/GatewayPaymentIntentService.ts', import.meta.url),
  'utf8',
);
const routes = readFileSync(new URL('../src/routes/internal/index.ts', import.meta.url), 'utf8');

test('gateway payment intents, challenges, and result events are durable', () => {
  assert.match(migration, /CREATE TABLE IF NOT EXISTS public\.gateway_payment_intents/);
  assert.match(migration, /intent_id TEXT NOT NULL UNIQUE/);
  assert.match(migration, /request_hash TEXT NOT NULL/);
  assert.match(migration, /CREATE TABLE IF NOT EXISTS public\.gateway_payment_challenges/);
  assert.match(migration, /challenge_id TEXT NOT NULL UNIQUE/);
  assert.match(migration, /CREATE TABLE IF NOT EXISTS public\.gateway_payment_event_outbox/);
  assert.match(migration, /event_key TEXT NOT NULL UNIQUE/);
});

test('intent persistence rejects mismatched replays under row lock', () => {
  assert.match(migration, /CREATE OR REPLACE FUNCTION public\.persist_gateway_payment_intent_v1/);
  assert.match(migration, /FROM public\.gateway_payment_intents[\s\S]*FOR UPDATE/);
  assert.match(migration, /GATEWAY_INTENT_REPLAY_MISMATCH/);
  assert.match(migration, /'replayed', TRUE/);
  assert.match(migration, /INSERT INTO public\.gateway_payment_challenges/);
  assert.match(migration, /INSERT INTO public\.gateway_payment_event_outbox/);
});

test('gateway intent functions and tables are service-role only', () => {
  assert.match(migration, /ALTER TABLE public\.gateway_payment_intents ENABLE ROW LEVEL SECURITY/);
  assert.match(migration, /ALTER TABLE public\.gateway_payment_challenges ENABLE ROW LEVEL SECURITY/);
  assert.match(migration, /REVOKE ALL ON FUNCTION public\.persist_gateway_payment_intent_v1[\s\S]*FROM PUBLIC/);
  assert.match(migration, /GRANT EXECUTE ON FUNCTION public\.persist_gateway_payment_intent_v1[\s\S]*TO service_role/);
});

test('service payment route persists before sending result to Pay Gateway', () => {
  const persistIndex = routes.indexOf('gatewayPaymentIntentService.persist');
  const deliveryIndex = routes.indexOf('postServicePaymentEventToPayGateway(event)');
  assert.ok(persistIndex > 0);
  assert.ok(deliveryIndex > persistIndex);
  assert.match(routes, /durableReplay:\s*persistence\.replayed === true/);
  assert.match(routes, /gatewayPaymentIntentService\.recordDelivery/);
});

test('intent service hashes canonical payloads and uses SQL RPCs', () => {
  assert.match(service, /stableSerialize/);
  assert.match(service, /createHash\('sha256'\)/);
  assert.match(service, /\.rpc\('persist_gateway_payment_intent_v1'/);
  assert.match(service, /\.rpc\('record_gateway_payment_event_delivery_v1'/);
  assert.doesNotMatch(service, /new Map/);
});
