import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import test from 'node:test';

const bankingEngine = readFileSync(
  new URL('../backend/ledger/transactionEngine.ts', import.meta.url),
  'utf8',
);
const enterpriseProcessor = readFileSync(
  new URL('../backend/enterprise/wealth/EnterprisePaymentProcessor.ts', import.meta.url),
  'utf8',
);
const coreFinanceRoutes = readFileSync(
  new URL('../src/routes/public/coreFinance.ts', import.meta.url),
  'utf8',
);
const transactionService = readFileSync(
  new URL('../ledger/transactionService.ts', import.meta.url),
  'utf8',
);

test('internal transfer settlement is attempted before the banking response is built', () => {
  assert.match(
    bankingEngine,
    /await this\.completeSettlement\(txId, undefined, `engine:auto:\$\{txId\}`\)/,
  );
  assert.match(
    bankingEngine,
    /\.from\('transactions'\)\s*\.select\('status'\)\s*\.eq\('id', txId\)/,
  );
  assert.doesNotMatch(
    bankingEngine,
    /this\.completeSettlement\(txId, undefined, `engine:auto:\$\{txId\}`\)\.catch/,
  );
});

test('enterprise response and events use the actual ledger transaction status', () => {
  assert.match(enterpriseProcessor, /status: finalTx\.status \|\| 'processing'/);
  assert.match(
    enterpriseProcessor,
    /finalStatus === 'completed' \|\| finalStatus === 'settled'/,
  );
  assert.match(enterpriseProcessor, /'fintech\.transaction\.processing'/);
});

test('clients can query an owned transaction until it reaches a terminal status', () => {
  assert.match(
    coreFinanceRoutes,
    /v1\.get\('\/transactions\/:id', authenticate as any/,
  );
  assert.match(
    transactionService,
    /public async getTransactionForUser\(userId: string, transactionId: string\)/,
  );
  assert.match(
    transactionService,
    /ownedWalletIds\.has\(String\(row\.to_wallet_id \|\| ''\)\)/,
  );
});
