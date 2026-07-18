import { resolveOperatingWealthWalletStrict, wealthNumber } from './wealthShared.js';

const sharedBudgetWithdrawalTypes = new Set([
  'SHARED_BUDGET_WITHDRAWAL_TO_ACCOUNT',
  'SHARED_BUDGET_AGENT_CASHOUT',
]);

const normalizeSharedBudgetSpendType = (value: any) => {
  const normalized = String(value || '').trim().toUpperCase();
  if (normalized === 'WITHDRAW_TO_ACCOUNT') return 'SHARED_BUDGET_WITHDRAWAL_TO_ACCOUNT';
  if (normalized === 'WITHDRAW_TO_ORBI_AGENT') return 'SHARED_BUDGET_AGENT_CASHOUT';
  return normalized || 'EXTERNAL_PAYMENT';
};

export const createSharedBudgetSpendExecutor = (LogicCore: any) => async (
  sb: any,
  {
    budget,
    membership,
    actorUserId,
    actorUser,
    payload,
    approvalId,
  }: {
    budget: any;
    membership: any;
    actorUserId: string;
    actorUser: any;
    payload: any;
    approvalId?: string | null;
  },
) => {
  const currentSpent = wealthNumber(budget.spent_amount);
  const budgetLimit = wealthNumber(budget.budget_limit);
  const fundedAmount = wealthNumber(budget.funded_amount || 0);
  const fundedAvailable = Math.max(0, fundedAmount - currentSpent);
  if (currentSpent + payload.amount > budgetLimit) {
    throw new Error('SHARED_BUDGET_LIMIT_EXCEEDED');
  }
  if (payload.amount > fundedAvailable) {
    throw new Error('SHARED_BUDGET_FUNDS_REQUIRED');
  }

  const memberSpent = wealthNumber(membership.spent_amount || 0);
  if (membership.member_limit && memberSpent + payload.amount > wealthNumber(membership.member_limit)) {
    throw new Error('SHARED_BUDGET_MEMBER_LIMIT_EXCEEDED');
  }

  const { sourceRecord, sourceTable } = await resolveOperatingWealthWalletStrict(
    sb,
    actorUserId,
    payload.source_wallet_id || undefined,
  );
  const spendType = normalizeSharedBudgetSpendType(payload.type);
  const isWithdrawalIntent = sharedBudgetWithdrawalTypes.has(spendType);
  const withdrawalDestination = spendType === 'SHARED_BUDGET_AGENT_CASHOUT'
    ? 'ORBI_AGENT'
    : spendType === 'SHARED_BUDGET_WITHDRAWAL_TO_ACCOUNT'
      ? 'OPERATING_WALLET'
      : null;

  const enrichedMetadata = {
    ...(payload.metadata || {}),
    shared_budget_id: budget.id,
    shared_budget_name: budget.name,
    shared_budget_role: membership.role || 'SPENDER',
    bill_provider: payload.provider || null,
    bill_category: payload.bill_category || null,
    bill_reference: payload.reference || null,
    spend_origin: 'SHARED_BUDGET',
    spend_type: spendType,
    withdrawal_destination: withdrawalDestination,
    approval_id: approvalId || null,
    approval_mode: budget.approval_mode || 'AUTO',
    actor_user_id: actorUserId,
    member_user_id: actorUserId,
    source_wallet_id: sourceRecord.id,
    source_wallet_table: sourceTable,
    source_wallet_role: sourceRecord.vault_role || sourceRecord.type || null,
  };

  let result: any = { success: true, transaction: null };
  let transactionId: string | null = null;
  let budgetAlreadyUpdated = false;
  let newBudgetSpent = currentSpent + payload.amount;
  let newMemberSpent = memberSpent + payload.amount;
  let budgetAvailableAfter = Math.max(0, fundedAvailable - payload.amount);
  const currency = (payload.currency || budget.currency || 'TZS').toUpperCase();
  const description = payload.description || (
    isWithdrawalIntent
      ? `Mezani withdrawal: ${budget.name}`
      : `${budget.name} spend`
  );

  if (isWithdrawalIntent) {
    const reference = `budget_w_${payload.idempotencyKey || payload.idempotency_key}`;
    const { data: withdrawalResult, error: withdrawalError } = await sb.rpc('shared_budget_withdraw_v1', {
      p_user_id: actorUserId,
      p_budget_id: budget.id,
      p_target_wallet_id: sourceRecord.id,
      p_amount: payload.amount,
      p_currency: currency,
      p_description: description,
      p_reference_id: reference,
      p_metadata: {
        ...enrichedMetadata,
        reference_id: reference,
      },
    });
    if (withdrawalError) throw new Error(withdrawalError.message);
    transactionId = withdrawalResult?.transaction_id || null;
    newBudgetSpent = wealthNumber(withdrawalResult?.budget_spent_after ?? newBudgetSpent);
    budgetAvailableAfter = wealthNumber(withdrawalResult?.budget_available_after ?? budgetAvailableAfter);
    budgetAlreadyUpdated = true;
    if (transactionId) {
      const { data: withdrawalTx, error: withdrawalTxError } = await sb
        .from('transactions')
        .select('*')
        .eq('id', transactionId)
        .maybeSingle();
      if (withdrawalTxError) throw new Error(withdrawalTxError.message);
      result = { success: true, transaction: withdrawalTx };
    }
  } else {
    const paymentPayload = {
      sourceWalletId: sourceRecord.id,
      recipientId: payload.provider,
      amount: payload.amount,
      currency,
      description,
      type: spendType,
      metadata: enrichedMetadata,
      quoteId: payload.quoteId || payload.quote_id,
      quoteHash: payload.quoteHash || payload.quote_hash,
      idempotencyKey: payload.idempotencyKey,
    };
    const bound = paymentPayload.quoteId
      ? await LogicCore.bindSettlementQuote(actorUserId, paymentPayload, String(payload.idempotencyKey || ''))
      : null;
    result = await LogicCore.processSecurePayment(bound?.payload || paymentPayload, actorUser);
    if (bound?.quoteId) {
      await LogicCore.markSettlementQuoteResult(actorUserId, bound.quoteId, result);
    }
    if (!result.success) throw new Error(result.error || 'SHARED_BUDGET_SPEND_FAILED');

    const tx = result.transaction || {};
    transactionId = tx.internalId || tx.id || null;
  }
  const nowIso = new Date().toISOString();

  if (transactionId) {
    const { error: txLinkError } = await sb
      .from('transactions')
      .update({
        shared_budget_id: budget.id,
        updated_at: nowIso,
        metadata: enrichedMetadata,
      })
      .eq('id', transactionId);
    if (txLinkError) throw new Error(txLinkError.message);

    const { error: ledgerLinkError } = await sb
      .from('financial_ledger')
      .update({ shared_budget_id: budget.id })
      .eq('transaction_id', transactionId);
    if (ledgerLinkError) throw new Error(ledgerLinkError.message);
  }

  if (!budgetAlreadyUpdated) {
    const { error: budgetUpdateError } = await sb
      .from('shared_budgets')
      .update({
        spent_amount: newBudgetSpent,
        updated_at: nowIso,
      })
      .eq('id', budget.id);
    if (budgetUpdateError) throw new Error(budgetUpdateError.message);
  }

  if (!budgetAlreadyUpdated) {
    const { error: memberUpdateError } = await sb
      .from('shared_budget_members')
      .upsert({
        budget_id: budget.id,
        user_id: actorUserId,
        role: membership.role || 'SPENDER',
        status: membership.status || 'ACTIVE',
        member_limit: membership.member_limit || null,
        spent_amount: newMemberSpent,
        metadata: membership.metadata || {},
      }, {
        onConflict: 'budget_id,user_id',
      });
    if (memberUpdateError) throw new Error(memberUpdateError.message);
  }

  const { data: budgetTx, error: budgetTxError } = await sb
      .from('shared_budget_transactions')
    .insert({
      shared_budget_id: budget.id,
      member_user_id: actorUserId,
      source_wallet_id: sourceRecord.id,
      transaction_id: transactionId,
      merchant_name: isWithdrawalIntent ? withdrawalDestination : (payload.provider || result.transaction?.toUserId || null),
      provider: payload.provider || null,
      category: payload.bill_category || spendType || 'SPEND',
      amount: payload.amount,
      currency,
      status: 'COMPLETED',
      note: payload.description || null,
      metadata: {
        ...enrichedMetadata,
        reference: payload.reference || null,
        approved_from_review: approvalId != null,
      },
    })
    .select('*')
    .single();
  if (budgetTxError) throw new Error(budgetTxError.message);

  return {
    transaction: result.transaction,
    budget_transaction: budgetTx,
    shared_budget: {
      ...budget,
      spent_amount: newBudgetSpent,
      funded_amount: fundedAmount,
      remaining_amount: budgetAvailableAfter,
    },
    member: {
      ...membership,
      spent_amount: newMemberSpent,
    },
  };
};
