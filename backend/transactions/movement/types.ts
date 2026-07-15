export type TransactionMovementFamily =
  | 'INTERNAL_P2P'
  | 'INTERNAL_SS'
  | 'EXTERNAL'
  | 'UNKNOWN';

export interface TransactionMovementClassification {
  movement_family: TransactionMovementFamily;
  movement_code: string;
  movement_group: string;
  source_context: string;
  destination_context: string;
  is_internal: boolean;
  is_self_service: boolean;
  is_p2p: boolean;
  is_external: boolean;
}

export interface TransactionMovementClassifierInput {
  transaction: any;
  legs?: any[];
  walletMap?: Record<string, any> | Map<string, any>;
  userId?: string;
}
