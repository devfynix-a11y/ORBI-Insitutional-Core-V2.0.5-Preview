export type EntTxState = 'INITIATED' | 'AUTHORIZED' | 'PROCESSING' | 'HELD_FOR_REVIEW' | 'SETTLED' | 'FAILED' | 'REVERSED' | 'EXPIRED';
export type EntJournalDirection = 'CREDIT' | 'DEBIT';

export interface IdempotencyRecord {
    key: string;
    client_id: string;
    request_path: string;
    response_status?: number;
    response_body?: any;
    created_at: string;
    expires_at: string;
}

export interface EntTransaction {
    id: string;
    idempotency_key: string;
    reference_id: string;
    state: EntTxState;
    amount: number;
    currency: string;
    metadata: any;
    created_at: string;
    updated_at: string;
}

export interface EntLedgerJournal {
    id: string;
    transaction_id: string;
    wallet_id: string;
    direction: EntJournalDirection;
    amount: number;
    currency: string;
    created_at: string;
}

export interface SystemVault {
    id: string;
    vault_purpose: string;
    wallet_id: string;
    is_active: boolean;
}

export interface CloudEvent {
    specversion: string;
    type: string;
    source: string;
    id: string;
    time: string;
    datacontenttype: string;
    data: any;
}
