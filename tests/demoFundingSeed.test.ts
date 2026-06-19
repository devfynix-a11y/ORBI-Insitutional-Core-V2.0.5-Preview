import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import test from 'node:test';

const seed = readFileSync(
  new URL('../database/demo/20260618_fund_demo_users.sql', import.meta.url),
  'utf8',
);

test('demo funding is sandbox guarded and targets only named customers', () => {
  assert.match(seed, /DEMO_SEED_SANDBOX_PROVIDER_REQUIRED/);
  assert.match(seed, /OB26-2531-8566/);
  assert.match(seed, /OB26-2980-5415/);
  assert.match(seed, /DEMO_SEED_TARGET_USERS_INVALID/);
});

test('demo funding creates a balanced auditable opening balance', () => {
  assert.match(seed, /DEMO_CLEARING_SOURCE/);
  assert.match(seed, /DEMO_OPENING_EQUITY/);
  assert.match(seed, /'DEBIT'[\s\S]*'200000'[\s\S]*'-200000'/);
  assert.match(seed, /'CREDIT'[\s\S]*'200000'[\s\S]*'200000'/);
});

test('demo user deposits use SQL-authoritative transaction posting', () => {
  assert.match(seed, /PERFORM public\.post_transaction_v2/);
  assert.match(seed, /DEMO-DEPOSIT-/);
  assert.match(seed, /'DEBIT'[\s\S]*'amount_plain', 100000/);
  assert.match(seed, /'CREDIT'[\s\S]*'amount_plain', 100000/);
  assert.match(seed, /WHERE reference_id = v_reference_id/);
});
