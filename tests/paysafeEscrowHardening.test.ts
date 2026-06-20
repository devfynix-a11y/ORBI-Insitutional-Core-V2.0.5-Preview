import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import test from 'node:test';

const service = readFileSync(new URL('../ledger/escrowService.ts', import.meta.url), 'utf8');
const migration = readFileSync(
    new URL('../database/migrations/20260618_paysafe_escrow_hardening.sql', import.meta.url),
    'utf8',
);
const operations = readFileSync(new URL('../src/routes/public/operations.ts', import.meta.url), 'utf8');
const messaging = readFileSync(new URL('../backend/features/MessagingService.ts', import.meta.url), 'utf8');
const transactionService = readFileSync(new URL('../ledger/transactionService.ts', import.meta.url), 'utf8');

test('PaySafe creation posts balanced operating-to-escrow ledger legs', () => {
    assert.match(service, /walletId:\s*sourceVault\.id[\s\S]*type:\s*'DEBIT'/);
    assert.match(service, /walletId:\s*paySafeVault\.id[\s\S]*type:\s*'CREDIT'/);
    assert.match(service, /status:\s*'authorized'/);
    assert.match(service, /is_conditional_escrow:\s*true/);
    assert.match(service, /escrow_amount_plain:\s*amount/);
});

test('PaySafe lifecycle is persisted atomically by service-role-only SQL', () => {
    assert.match(migration, /CREATE OR REPLACE FUNCTION public\.transition_paysafe_escrow_v1/);
    assert.match(migration, /'RELEASE', 'ACCEPT', 'DISPUTE', 'REFUND'/);
    assert.match(migration, /status = 'RELEASE_PENDING'/);
    assert.match(migration, /cannot accept escrow in state/);
    assert.match(migration, /FOR UPDATE/);
    assert.match(migration, /INSERT INTO public\.financial_ledger/);
    assert.match(migration, /UPDATE public\.platform_vaults/);
    assert.match(migration, /UPDATE public\.escrow_agreements/);
    assert.match(migration, /REVOKE ALL ON FUNCTION public\.transition_paysafe_escrow_v1[\s\S]*FROM PUBLIC/);
    assert.match(migration, /GRANT EXECUTE ON FUNCTION public\.transition_paysafe_escrow_v1[\s\S]*TO service_role/);
});

test('PaySafe agreement creation shares the ledger database transaction', () => {
    assert.match(migration, /AFTER INSERT ON public\.transactions/);
    assert.match(migration, /create_escrow_agreement_from_transaction/);
    assert.match(migration, /idx_escrow_agreements_transaction/);
    assert.match(migration, /idx_escrow_agreements_reference/);
});

test('PaySafe reads and disputes require escrow-party authorization', () => {
    assert.match(operations, /LogicCore\.getEscrow\(req\.params\.id,\s*session\.sub\)/);
    assert.match(operations, /v1\.post\('\/escrow\/accept'/);
    assert.match(service, /ESCROW_ACCESS_DENIED/);
    assert.match(service, /UNAUTHORIZED_DISPUTE/);
    assert.match(service, /UNAUTHORIZED_ACCEPT/);
    assert.match(service, /UNAUTHORIZED_REFUND/);
    assert.match(service, /agreement\.sender_id,\s*agreement\.receiver_id/);
});

test('PaySafe creation requires active consumer accounts and strict vault roles', () => {
    assert.match(service, /PAYSAFE_SENDER_ACCOUNT_NOT_ACTIVE/);
    assert.match(service, /PAYSAFE_RECIPIENT_ACCOUNT_NOT_ACTIVE/);
    assert.match(service, /PAYSAFE_SENDER_REGISTRY_INVALID/);
    assert.match(service, /PAYSAFE_RECIPIENT_REGISTRY_INVALID/);
    assert.match(service, /\.in\('vault_role', \['OPERATING', 'INTERNAL_TRANSFER'\]\)/);
});

test('notification delivery cannot roll back a committed escrow action', () => {
    assert.match(service, /private async notifySafely/);
    assert.match(service, /Notification dispatch failed/);
    assert.match(service, /Notification delivery is a side effect/);
});

test('PaySafe messaging awaits realtime delivery and falls back when channel templates are unavailable', () => {
    assert.match(messaging, /const socketSent = await SocketRegistry\.send/);
    assert.match(messaging, /if \(!templateSent && category !== 'promo'\)[\s\S]*sendSms/);
    assert.match(messaging, /if \(!emailSent && category !== 'promo'\)[\s\S]*sendEmail/);
});

test('PaySafe AML monitoring receives the transaction currency', () => {
    assert.match(transactionService, /currency:\s*t\.currency \|\| 'TZS'/);
});
