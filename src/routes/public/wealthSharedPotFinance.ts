import crypto from 'crypto';

type SharedPotFinanceInput = {
  sb: any;
  sessionUserId: string;
  pot: any;
  membership: any;
  payload: any;
  wealthNumber: (value: any) => number;
  resolveWealthSourceWallet: (
    sb: any,
    userId: string,
    sourceWalletId?: string,
  ) => Promise<any>;
};

const financialReference = (prefix: string, idempotencyKey?: string) => {
  const supplied = String(idempotencyKey || '').trim();
  if (supplied) {
    return `${prefix}_${supplied}`;
  }
  return `${prefix}_${Date.now()}_${crypto.randomBytes(8).toString('hex')}`;
};

const throwRpcError = (error: any, functionName: string): never => {
  const code = String(error?.code || '');
  if (code === 'PGRST202' || code === '42883') {
    throw new Error(`SHARED_POT_ATOMIC_RPC_UNAVAILABLE:${functionName}`);
  }
  throw new Error(String(error?.message || 'SHARED_POT_ATOMIC_OPERATION_FAILED'));
};

export const contributeToSharedPot = async (input: SharedPotFinanceInput) => {
  const {
    sb,
    sessionUserId,
    pot,
    membership,
    payload,
    wealthNumber,
    resolveWealthSourceWallet,
  } = input;
  const { sourceRecord, sourceTable } = await resolveWealthSourceWallet(
    sb,
    sessionUserId,
    payload.source_wallet_id,
  );
  const currentBalance = wealthNumber(sourceRecord.balance);
  if (currentBalance < payload.amount) {
    throw new Error('INSUFFICIENT_FUNDS');
  }

  const reference = financialReference('pot', payload.idempotency_key);
  const { data, error } = await sb.rpc('shared_pot_contribute_v1', {
    p_user_id: sessionUserId,
    p_pot_id: pot.id,
    p_source_wallet_id: sourceRecord.id,
    p_amount: payload.amount,
    p_currency: String(pot.currency || sourceRecord.currency || 'TZS').toUpperCase(),
    p_description: `Shared pot contribution: ${pot.name}`,
    p_reference_id: reference,
    p_metadata: {
      shared_pot_id: pot.id,
      source_table: sourceTable,
      source_wallet_role: sourceRecord.vault_role || sourceRecord.type || null,
    },
  });

  if (error) {
    throwRpcError(error, 'shared_pot_contribute_v1');
  }

  const txId = data?.transaction_id || null;
  let transaction = null;
  if (txId) {
    const { data: tx } = await sb
      .from('transactions')
      .select('*')
      .eq('id', txId)
      .maybeSingle();
    transaction = tx || null;
  }

  return {
    transaction,
    shared_pot: {
      ...pot,
      current_amount: Number(data?.pot_balance_after ?? pot.current_amount),
    },
    source_balance: Number(data?.source_balance_after ?? currentBalance),
    member_role: membership.role,
    atomic_commit: true,
    idempotent: Boolean(data?.idempotent),
  };
};

export const withdrawFromSharedPot = async (input: SharedPotFinanceInput) => {
  const {
    sb,
    sessionUserId,
    pot,
    membership,
    payload,
    wealthNumber,
    resolveWealthSourceWallet,
  } = input;
  const currentPotBalance = wealthNumber(pot.current_amount);
  if (currentPotBalance < payload.amount) {
    throw new Error('INSUFFICIENT_POT_FUNDS');
  }

  const { sourceRecord: targetRecord, sourceTable: targetTable } =
    await resolveWealthSourceWallet(
      sb,
      sessionUserId,
      payload.target_wallet_id,
    );
  const reference = financialReference('pot_w', payload.idempotency_key);
  const { data, error } = await sb.rpc('shared_pot_withdraw_v1', {
    p_user_id: sessionUserId,
    p_pot_id: pot.id,
    p_target_wallet_id: targetRecord.id,
    p_amount: payload.amount,
    p_currency: String(pot.currency || targetRecord.currency || 'TZS').toUpperCase(),
    p_description: `Shared pot withdrawal: ${pot.name}`,
    p_reference_id: reference,
    p_metadata: {
      shared_pot_id: pot.id,
      target_table: targetTable,
      target_wallet_role: targetRecord.vault_role || targetRecord.type || null,
    },
  });

  if (error) {
    throwRpcError(error, 'shared_pot_withdraw_v1');
  }

  const txId = data?.transaction_id || null;
  let transaction = null;
  if (txId) {
    const { data: tx } = await sb
      .from('transactions')
      .select('*')
      .eq('id', txId)
      .maybeSingle();
    transaction = tx || null;
  }

  return {
    transaction,
    shared_pot: {
      ...pot,
      current_amount: Number(data?.pot_balance_after ?? pot.current_amount),
    },
    target_balance: Number(data?.target_balance_after ?? targetRecord.balance),
    member_role: membership.role,
    atomic_commit: true,
    idempotent: Boolean(data?.idempotent),
  };
};
