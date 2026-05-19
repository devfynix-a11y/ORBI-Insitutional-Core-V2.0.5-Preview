import { MoneyOperation, RailType } from '../../types.js';

export type TransactionFeeClassification = {
  transactionType: string;
  transactionModel: string;
  flowCode: string;
  operationType: string;
  direction: string;
  rail?: RailType | string;
  channel?: string;
  categoryCode?: string;
  categoryId?: string;
  serviceContext?: string;
};

type ClassificationInput = {
  type?: string;
  category?: string;
  categoryId?: string | number;
  metadata?: Record<string, any>;
  channel?: string;
  rail?: string;
  operation?: string;
};

const EXTERNAL_TYPES = new Set(['EXTERNAL_PAYMENT', 'BILL_PAYMENT', 'WITHDRAWAL', 'DEPOSIT', 'MERCHANT_PAYMENT']);

export class TransactionFeeClassifier {
  classify(input: ClassificationInput): TransactionFeeClassification {
    const metadata = input.metadata && typeof input.metadata === 'object' ? input.metadata : {};
    const transactionType = this.normalizeType(input.type);
    const serviceContext = this.normalize(metadata.service_context);
    const cashDirection = this.normalize(metadata.cash_direction).toLowerCase();
    const categoryCode = this.normalizeCategoryCode(
      metadata.fee_category ||
      metadata.category_code ||
      metadata.bill_category ||
      metadata.service_category ||
      input.category,
    );
    const categoryId = this.normalizeNullable(input.categoryId ?? metadata.category_id ?? metadata.categoryId);
    const rail = this.resolveRail(input.rail || metadata.rail || metadata.provider_rail, transactionType);
    const operationType = this.resolveOperationType(input.operation || metadata.operation || metadata.operation_code, transactionType, serviceContext, cashDirection);
    const direction = this.resolveDirection(metadata.direction, transactionType, serviceContext, cashDirection);
    const flowCode = this.resolveFlowCode(metadata.flowCode || metadata.flow_code, transactionType, serviceContext, cashDirection);

    return {
      transactionType,
      transactionModel: this.resolveTransactionModel(transactionType, serviceContext, rail),
      flowCode,
      operationType,
      direction,
      rail,
      channel: this.normalizeNullable(input.channel || metadata.channel || metadata.payment_channel),
      categoryCode,
      categoryId,
      serviceContext: serviceContext || undefined,
    };
  }

  resolveProviderOperation(classification: TransactionFeeClassification): MoneyOperation {
    const operation = this.normalize(classification.operationType);
    if (operation) return operation as MoneyOperation;
    if (classification.direction === 'EXTERNAL_TO_INTERNAL') return 'COLLECTION_REQUEST';
    return 'DISBURSEMENT_REQUEST';
  }

  private resolveFlowCode(explicit: any, transactionType: string, serviceContext: string, cashDirection: string) {
    const configured = this.normalize(explicit);
    if (configured) return configured;
    if (serviceContext === 'MERCHANT') return 'MERCHANT_PAYMENT';
    if (serviceContext === 'AGENT_CASH' && cashDirection === 'withdrawal') return 'AGENT_CASH_WITHDRAWAL';
    if (serviceContext === 'AGENT_CASH') return 'AGENT_CASH_DEPOSIT';
    if (serviceContext === 'SERVICE_COMMISSION' || serviceContext === 'SYSTEM') return 'SYSTEM_OPERATION';
    if (transactionType === 'BILL_PAYMENT') return 'EXTERNAL_PAYMENT';
    if (transactionType === 'EXTERNAL_PAYMENT') return 'EXTERNAL_PAYMENT';
    if (transactionType === 'WITHDRAWAL') return 'WITHDRAWAL';
    if (transactionType === 'DEPOSIT') return 'DEPOSIT';
    if (transactionType === 'INTERNAL_TRANSFER' || transactionType === 'PEER_TRANSFER') return 'INTERNAL_TRANSFER';
    return 'CORE_TRANSACTION';
  }

  private resolveTransactionModel(transactionType: string, serviceContext: string, rail?: RailType | string) {
    if (serviceContext === 'AGENT_CASH') return 'AGENT_CASH';
    if (serviceContext === 'MERCHANT' || transactionType === 'MERCHANT_PAYMENT') return 'MERCHANT_PAYMENT';
    if (transactionType === 'BILL_PAYMENT') return 'BILL_PAYMENT';
    if (transactionType === 'INTERNAL_TRANSFER' || transactionType === 'PEER_TRANSFER') return 'WALLET_TRANSFER';
    if (EXTERNAL_TYPES.has(transactionType)) return `EXTERNAL_${rail || 'WALLET'}`;
    return 'CORE_LEDGER';
  }

  private resolveOperationType(explicit: any, transactionType: string, serviceContext: string, cashDirection: string) {
    const configured = this.normalize(explicit);
    if (configured) return configured;
    if (serviceContext === 'AGENT_CASH' && cashDirection === 'withdrawal') return 'DISBURSEMENT_REQUEST';
    if (serviceContext === 'AGENT_CASH') return 'COLLECTION_REQUEST';
    if (transactionType === 'DEPOSIT') return 'COLLECTION_REQUEST';
    if (transactionType === 'WITHDRAWAL' || transactionType === 'EXTERNAL_PAYMENT' || transactionType === 'BILL_PAYMENT' || transactionType === 'MERCHANT_PAYMENT') {
      return 'DISBURSEMENT_REQUEST';
    }
    if (transactionType === 'INTERNAL_TRANSFER' || transactionType === 'PEER_TRANSFER') return 'LEDGER_TRANSFER';
    return 'CORE_TRANSACTION';
  }

  private resolveDirection(explicit: any, transactionType: string, serviceContext: string, cashDirection: string) {
    const configured = this.normalize(explicit);
    if (configured) return configured;
    if (serviceContext === 'AGENT_CASH' && cashDirection === 'deposit') return 'EXTERNAL_TO_INTERNAL';
    if (serviceContext === 'AGENT_CASH' && cashDirection === 'withdrawal') return 'INTERNAL_TO_EXTERNAL';
    if (transactionType === 'DEPOSIT') return 'EXTERNAL_TO_INTERNAL';
    if (transactionType === 'WITHDRAWAL' || transactionType === 'EXTERNAL_PAYMENT' || transactionType === 'BILL_PAYMENT' || transactionType === 'MERCHANT_PAYMENT') {
      return 'INTERNAL_TO_EXTERNAL';
    }
    return 'INTERNAL_TO_INTERNAL';
  }

  private resolveRail(value: any, transactionType: string): RailType | string | undefined {
    const rail = this.normalize(value);
    if (rail) return rail;
    if (transactionType === 'INTERNAL_TRANSFER' || transactionType === 'PEER_TRANSFER') return 'WALLET';
    return 'MOBILE_MONEY';
  }

  private normalizeType(value: any) {
    const normalized = this.normalize(value || 'INTERNAL_TRANSFER');
    if (normalized === 'INTERNAL') return 'INTERNAL_TRANSFER';
    if (normalized === 'EXTERNAL') return 'EXTERNAL_PAYMENT';
    return normalized;
  }

  private normalizeCategoryCode(value: any) {
    const normalized = this.normalize(value);
    return normalized || undefined;
  }

  private normalizeNullable(value: any) {
    const normalized = String(value ?? '').trim();
    return normalized || undefined;
  }

  private normalize(value: any) {
    return String(value ?? '').trim().toUpperCase();
  }
}

export const transactionFeeClassifier = new TransactionFeeClassifier();
