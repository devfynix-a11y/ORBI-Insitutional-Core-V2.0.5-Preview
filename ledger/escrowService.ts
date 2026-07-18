import { getSupabase, getAdminSupabase } from '../services/supabaseClient.js';
import { TransactionService } from './transactionService.js';
import { Messaging } from '../backend/features/MessagingService.js';
import { Audit } from '../backend/security/audit.js';
import { WalletResolverService } from '../backend/wealth/WalletResolver.js';
import { platformFeeService } from '../backend/payments/PlatformFeeService.js';
import { UUID } from '../services/utils.js';

export type EscrowStatus =
    | 'HELD'
    | 'RELEASE_PENDING'
    | 'RETURN_PENDING'
    | 'RELEASED'
    | 'DISPUTED'
    | 'REFUNDED';

type EscrowAgreementRecord = {
    id: string;
    transaction_id: string;
    reference_id: string;
    sender_id: string;
    receiver_id: string;
    source_vault_id: string;
    escrow_vault_id: string;
    receiver_vault_id?: string | null;
    merchant_id?: string | null;
    service_code?: string | null;
    amount: number | string;
    currency: string;
    conditions?: Record<string, unknown>;
    status: EscrowStatus;
    expires_at?: string | null;
    release_requested_at?: string | null;
    release_requested_by?: string | null;
    receiver_accepted_at?: string | null;
    receiver_accepted_by?: string | null;
    metadata?: Record<string, unknown>;
    transaction?: Record<string, any> | null;
};

export class EscrowService {
    private readonly txService = new TransactionService();

    public async createEscrow(
        senderId: string,
        recipientIdentifier: string,
        amount: number,
        description: string,
        conditions: Record<string, unknown> = {},
    ): Promise<string> {
        const sb = getAdminSupabase() || getSupabase();
        if (!sb) throw new Error('VAULT_OFFLINE');
        if (!Number.isFinite(amount) || amount <= 0) throw new Error('PAYSAFE_AMOUNT_INVALID');
        if (!String(description || '').trim()) throw new Error('PAYSAFE_DESCRIPTION_REQUIRED');

        const recipient = await WalletResolverService.resolveWallet(recipientIdentifier, 'OPERATING');
        if (!recipient) throw new Error('RECIPIENT_NOT_FOUND');
        if (recipient.userId === senderId) throw new Error('PAYSAFE_SELF_ESCROW_NOT_ALLOWED');

        const [
            { data: accountRecords, error: accountError },
            { data: senderVaults, error: senderVaultError },
            { data: recipientVaults, error: recipientVaultError },
        ] = await Promise.all([
            sb
                .from('users')
                .select('id,account_status,registry_type,full_name')
                .in('id', [senderId, recipient.userId]),
            sb
                .from('platform_vaults')
                .select('id,user_id,vault_role,currency,status,is_locked,balance')
                .eq('user_id', senderId)
                .in('vault_role', ['OPERATING', 'INTERNAL_TRANSFER']),
            sb
                .from('platform_vaults')
                .select('id,user_id,vault_role,currency,status,is_locked,balance')
                .eq('user_id', recipient.userId)
                .eq('vault_role', 'OPERATING'),
        ]);
        if (accountError) throw new Error('PAYSAFE_ACCOUNT_LOOKUP_FAILED');
        const accountById = new Map((accountRecords || []).map((record: any) => [String(record.id), record]));
        const senderAccount = accountById.get(senderId);
        const recipientAccount = accountById.get(recipient.userId);
        if (!senderAccount || String(senderAccount.account_status || '').toLowerCase() !== 'active') {
            throw new Error('PAYSAFE_SENDER_ACCOUNT_NOT_ACTIVE');
        }
        if (!recipientAccount || String(recipientAccount.account_status || '').toLowerCase() !== 'active') {
            throw new Error('PAYSAFE_RECIPIENT_ACCOUNT_NOT_ACTIVE');
        }
        if (String(senderAccount.registry_type || '').toUpperCase() !== 'CONSUMER') {
            throw new Error('PAYSAFE_SENDER_REGISTRY_INVALID');
        }
        if (String(recipientAccount.registry_type || '').toUpperCase() !== 'CONSUMER') {
            throw new Error('PAYSAFE_RECIPIENT_REGISTRY_INVALID');
        }
        if (senderVaultError || recipientVaultError) throw new Error('PAYSAFE_VAULT_LOOKUP_FAILED');
        const isUsableVault = (vault: any) => !Boolean(vault.is_locked)
            && !['locked', 'frozen', 'blocked', 'suspended'].includes(String(vault.status || '').toLowerCase());
        const sourceVault = (senderVaults || [])
            .filter((vault: any) => vault.vault_role === 'OPERATING' && isUsableVault(vault))
            .sort((a: any, b: any) => Number(b.balance || 0) - Number(a.balance || 0))
            .find((vault: any) => Number(vault.balance || 0) >= amount);
        const paySafeVault = (senderVaults || [])
            .filter((vault: any) => vault.vault_role === 'INTERNAL_TRANSFER' && isUsableVault(vault))
            .sort((a: any, b: any) => Number(b.balance || 0) - Number(a.balance || 0))[0];
        const recipientVault = (recipientVaults || [])
            .filter((vault: any) => isUsableVault(vault))
            .sort((a: any, b: any) => Number(b.balance || 0) - Number(a.balance || 0))[0];
        if (!sourceVault) throw new Error('OPERATING_WALLET_REQUIRED');
        if (!paySafeVault) throw new Error('PAYSAFE_VAULT_NOT_FOUND');
        if (!recipientVault) throw new Error('RECIPIENT_VAULT_NOT_FOUND');

        const vaultIds = [sourceVault.id, paySafeVault.id, recipientVault.id];
        const { data: activeVaults, error: activeVaultError } = await sb
            .from('platform_vaults')
            .select('id,user_id,vault_role,currency,status,is_locked')
            .in('id', vaultIds);
        if (activeVaultError || (activeVaults || []).length !== 3) throw new Error('PAYSAFE_VAULT_LOOKUP_FAILED');
        if ((activeVaults || []).some((vault: any) =>
            Boolean(vault.is_locked)
            || ['locked', 'frozen', 'blocked', 'suspended'].includes(String(vault.status || '').toLowerCase())
        )) {
            throw new Error('PAYSAFE_VAULT_UNAVAILABLE');
        }

        const currency = String(sourceVault.currency || 'TZS').toUpperCase();
        if (
            currency !== String(paySafeVault.currency || 'TZS').toUpperCase()
            || currency !== String(recipientVault.currency || 'TZS').toUpperCase()
        ) {
            throw new Error('PAYSAFE_CURRENCY_MISMATCH');
        }

        const referenceId = `ESC-${UUID.generateShortCode(16)}`;
        const merchantId = typeof conditions.merchantId === 'string'
            ? conditions.merchantId.trim()
            : typeof conditions.merchant_id === 'string'
                ? conditions.merchant_id.trim()
                : '';
        const serviceCode = typeof conditions.serviceCode === 'string'
            ? conditions.serviceCode.trim()
            : typeof conditions.service_code === 'string'
                ? conditions.service_code.trim()
                : '';
        let merchantFeeSnapshot: Record<string, unknown> | null = null;
        if (merchantId) {
            const { data: merchant, error: merchantError } = await sb
                .from('merchants')
                .select('id,owner_user_id,status')
                .eq('id', merchantId)
                .maybeSingle();
            if (merchantError) throw new Error('PAYSAFE_MERCHANT_LOOKUP_FAILED');
            if (!merchant) throw new Error('PAYSAFE_MERCHANT_NOT_FOUND');
            if (String(merchant.status || '').toLowerCase() !== 'active') {
                throw new Error('PAYSAFE_MERCHANT_NOT_ACTIVE');
            }
            if (String(merchant.owner_user_id || '') !== recipient.userId) {
                throw new Error('PAYSAFE_MERCHANT_RECIPIENT_MISMATCH');
            }

            const fee = await platformFeeService.resolveFee({
                flowCode: 'MERCHANT_PAYMENT',
                amount,
                currency,
                transactionModel: 'MERCHANT_PAYMENT',
                transactionType: 'MERCHANT_PAYMENT',
                operationType: 'PAYSAFE_RELEASE',
                direction: 'INBOUND',
                rail: 'WALLET',
                channel: 'PAYSAFE',
                metadata: {
                    merchantId,
                    serviceCode: serviceCode || null,
                    referenceId,
                },
            });
            if (fee.totalFee < 0 || fee.netAmount <= 0 || fee.totalFee >= amount) {
                throw new Error('PAYSAFE_MERCHANT_FEE_INVALID');
            }
            merchantFeeSnapshot = {
                flowCode: fee.flowCode,
                configId: fee.configId,
                configName: fee.configName,
                currency: fee.currency,
                grossAmount: fee.amount,
                serviceFee: fee.serviceFee,
                taxAmount: fee.taxAmount,
                govFeeAmount: fee.govFeeAmount,
                stampDutyFixed: fee.stampDutyFixed,
                totalFee: fee.totalFee,
                netAmount: fee.netAmount,
                capturedAt: new Date().toISOString(),
            };
        }
        const holdWindowHours = this.resolveHoldWindowHours(conditions);
        const metadata = {
            is_conditional_escrow: true,
            recipient_id: recipient.userId,
            recipient_name: recipient.profile.full_name,
            source_vault_id: sourceVault.id,
            escrow_vault_id: paySafeVault.id,
            receiver_vault_id: recipientVault.id,
            escrow_amount_plain: amount,
            currency,
            conditions,
            hold_window_hours: holdWindowHours,
            receiver_acceptance_required: true,
            merchant_id: merchantId || null,
            service_code: serviceCode || null,
            merchant_fee_snapshot: merchantFeeSnapshot,
            escrow_status: 'HELD',
        };

        await this.txService.postTransactionWithLedger({
            user_id: senderId,
            walletId: sourceVault.id,
            toWalletId: paySafeVault.id,
            amount,
            currency,
            description: `PaySafe escrow: ${description}`,
            type: 'escrow',
            status: 'authorized',
            referenceId,
            metadata,
        }, [
            {
                transactionId: '',
                walletId: sourceVault.id,
                type: 'DEBIT',
                amount,
                currency,
                timestamp: new Date().toISOString(),
                description: `PaySafe hold: ${description}`,
            },
            {
                transactionId: '',
                walletId: paySafeVault.id,
                type: 'CREDIT',
                amount,
                currency,
                timestamp: new Date().toISOString(),
                description: `PaySafe escrow reserve: ${description}`,
            },
        ]);

        const senderName = String(senderAccount.full_name || 'ORBI customer').trim();
        const formattedAmount = `${currency} ${amount.toLocaleString()}`;

        await this.notifySafely(senderId, 'info', 'ORBI PaySafe created', {
            sw: `Umeunda PaySafe ya ${formattedAmount} kwa ${recipient.profile.full_name}. Fedha ziko salama hadi uthibitishe release.`,
            en: `You created a ${formattedAmount} PaySafe for ${recipient.profile.full_name}. Money is safe until you confirm release.`,
        }, {
            template: 'Escrow_Created',
            variables: {
                amount: amount.toLocaleString(),
                currency,
                senderName,
                recipientName: recipient.profile.full_name,
                refId: referenceId,
            },
        });

        await this.notifySafely(recipient.userId, 'info', 'ORBI PaySafe request received', {
            sw: `${senderName} ametengeneza PaySafe ya ${formattedAmount} kwa ajili yako. Fedha ziko salama hadi release ithibitishwe.`,
            en: `${senderName} created a ${formattedAmount} PaySafe for you. Money is safe until release is confirmed.`,
        }, {
            template: 'Escrow_Request_Received',
            variables: {
                amount: amount.toLocaleString(),
                currency,
                senderName,
                recipientName: recipient.profile.full_name,
                refId: referenceId,
            },
        });
        await Audit.log('FINANCIAL', senderId, 'ESCROW_CREATED', {
            referenceId,
            recipientId: recipient.userId,
            sourceVaultId: sourceVault.id,
            escrowVaultId: paySafeVault.id,
            amount,
            currency,
        });
        return referenceId;
    }

    public async releaseEscrow(referenceId: string, actorId: string): Promise<Record<string, any>> {
        const agreement = await this.getAgreement(referenceId);
        if (agreement.sender_id !== actorId) throw new Error('UNAUTHORIZED_RELEASE');
        const result = agreement.merchant_id
            ? await this.settleMerchantEscrow(referenceId, actorId)
            : await this.transition(referenceId, actorId, 'RELEASE');

        await this.notifySafely(agreement.receiver_id, 'info', 'ORBI PaySafe release requested', {
            sw: `Mtumaji ameomba ku-release PaySafe ${referenceId}. Kubali release ili fedha ziingie kwako, au kataa/fungua dispute kama kuna tatizo.`,
            en: `The sender requested release for PaySafe ${referenceId}. Accept the release to receive funds, or reject/open a dispute if something is wrong.`,
        }, {
            template: 'Escrow_Released',
            variables: {
                amount: Number(agreement.amount).toLocaleString(),
                currency: agreement.currency,
                refId: referenceId,
            },
        });
        await Audit.log('FINANCIAL', actorId, 'ESCROW_RELEASE_REQUESTED', {
            referenceId,
            recipientId: agreement.receiver_id,
            transactionId: agreement.transaction_id,
            idempotent: Boolean(result?.idempotent),
        });
        return result;
    }

    public async acceptEscrow(referenceId: string, actorId: string): Promise<Record<string, any>> {
        const agreement = await this.getAgreement(referenceId);
        if (agreement.receiver_id !== actorId) throw new Error('UNAUTHORIZED_ACCEPT');
        if (agreement.merchant_id) throw new Error('PAYSAFE_ACCEPT_NOT_SUPPORTED_FOR_MERCHANT');
        const result = await this.transition(referenceId, actorId, 'ACCEPT');
        const resultStatus = String(result?.status || '').toUpperCase();

        if (resultStatus === 'REFUNDED') {
            await Promise.all([
                this.notifySafely(agreement.sender_id, 'info', 'ORBI PaySafe return accepted', {
                    sw: `Ombi la kurejesha PaySafe ${referenceId} limekubaliwa. Fedha zimerejeshwa kwenye akaunti yako.`,
                    en: `The return request for PaySafe ${referenceId} was accepted. Funds have been returned to your account.`,
                }),
                this.notifySafely(agreement.receiver_id, 'info', 'ORBI PaySafe return accepted', {
                    sw: `Umeruhusu kurejesha PaySafe ${referenceId}. Hold hii imefungwa.`,
                    en: `You accepted the return for PaySafe ${referenceId}. This hold is now closed.`,
                }),
            ]);
        } else if (resultStatus === 'RELEASED') {
            const formattedAmount = `${agreement.currency} ${Number(agreement.amount).toLocaleString()}`;
            await Promise.all([
                this.notifySafely(agreement.sender_id, 'info', 'ORBI PaySafe release accepted', {
                    sw: `Mpokeaji amekubali release ya PaySafe ${referenceId}. ${formattedAmount} imehamishwa kwake.`,
                    en: `The recipient accepted release for PaySafe ${referenceId}. ${formattedAmount} has been credited to them.`,
                }),
                this.notifySafely(agreement.receiver_id, 'info', 'ORBI PaySafe funds received', {
                    sw: `Umeikubali release ya PaySafe ${referenceId}. ${formattedAmount} imeingia kwenye akaunti yako.`,
                    en: `You accepted release for PaySafe ${referenceId}. ${formattedAmount} has been credited to your account.`,
                }),
            ]);
        } else if (resultStatus === 'DISPUTED') {
            await Promise.all([
                this.notifySafely(agreement.sender_id, 'security', 'ORBI PaySafe flagged', {
                    sw: `PaySafe ${referenceId} imewekwa kwenye dispute kwa sababu dirisha la release limeisha. Huduma kwa wateja wataikagua.`,
                    en: `PaySafe ${referenceId} was flagged because the release window expired. Customer care will review it.`,
                }),
                this.notifySafely(agreement.receiver_id, 'security', 'ORBI PaySafe flagged', {
                    sw: `PaySafe ${referenceId} imewekwa kwenye dispute kwa sababu dirisha la release limeisha. Huduma kwa wateja wataikagua.`,
                    en: `PaySafe ${referenceId} was flagged because the release window expired. Customer care will review it.`,
                }),
            ]);
        } else {
            await Promise.all([
                this.notifySafely(agreement.sender_id, 'info', 'ORBI PaySafe confirmed', {
                    sw: `Mpokeaji amethibitisha PaySafe ${referenceId}. Sasa unaweza ku-release fedha.`,
                    en: `The recipient confirmed PaySafe ${referenceId}. You can now release the funds.`,
                }),
                this.notifySafely(agreement.receiver_id, 'info', 'ORBI PaySafe confirmed', {
                    sw: `Umethibitisha PaySafe ${referenceId}. Fedha bado ziko salama hadi mtumaji afanye release.`,
                    en: `You confirmed PaySafe ${referenceId}. Funds remain safe until the sender releases them.`,
                }),
            ]);
        }
        await Audit.log('FINANCIAL', actorId, resultStatus === 'REFUNDED' ? 'ESCROW_RETURN_ACCEPTED' : 'ESCROW_CONFIRMED', {
            referenceId,
            senderId: agreement.sender_id,
            transactionId: agreement.transaction_id,
            idempotent: Boolean(result?.idempotent),
        });
        return result;
    }

    public async disputeEscrow(referenceId: string, userId: string, reason: string): Promise<void> {
        const agreement = await this.getAgreement(referenceId);
        if (![agreement.sender_id, agreement.receiver_id].includes(userId)) {
            throw new Error('UNAUTHORIZED_DISPUTE');
        }
        if (!String(reason || '').trim()) throw new Error('DISPUTE_REASON_REQUIRED');
        const result = await this.transition(referenceId, userId, 'DISPUTE', null, reason);

        await Promise.all([
            this.notifySafely(agreement.sender_id, 'security', 'ORBI PaySafe dispute opened', {
                sw: `Malipo ya PaySafe ${referenceId} yamewekwa chini ya ukaguzi.`,
                en: `PaySafe payment ${referenceId} has been placed under review.`,
            }),
            this.notifySafely(agreement.receiver_id, 'security', 'ORBI PaySafe dispute opened', {
                sw: `Malipo ya PaySafe ${referenceId} yamewekwa chini ya ukaguzi.`,
                en: `PaySafe payment ${referenceId} has been placed under review.`,
            }),
        ]);
        await Audit.log('SECURITY', userId, 'ESCROW_DISPUTED', {
            referenceId,
            reason,
            transactionId: agreement.transaction_id,
            idempotent: Boolean(result?.idempotent),
        });
    }

    public async refundEscrow(referenceId: string, actorId: string, reason = 'PaySafe refund requested'): Promise<Record<string, any>> {
        const agreement = await this.getAgreement(referenceId);
        if (agreement.sender_id !== actorId) throw new Error('UNAUTHORIZED_REFUND');
        const result = await this.transition(referenceId, actorId, 'REFUND', agreement.source_vault_id, reason);

        const formattedAmount = `${agreement.currency} ${Number(agreement.amount).toLocaleString()}`;
        const resultStatus = String(result?.status || '').toUpperCase();
        if (resultStatus === 'RETURN_PENDING') {
            const autoRefundAt = result?.autoRefundAt ? new Date(String(result.autoRefundAt)).toISOString() : null;
            await Promise.all([
                this.notifySafely(agreement.sender_id, 'info', 'ORBI PaySafe return requested', {
                    sw: `Umeomba kurejesha PaySafe ${referenceId} ya ${formattedAmount}. Mpokeaji anaweza kukubali au kufungua dispute ndani ya saa 24.`,
                    en: `You requested a return for ${formattedAmount} PaySafe ${referenceId}. The recipient can accept or open a dispute within 24 hours.`,
                }, {
                    variables: {
                        amount: Number(agreement.amount).toLocaleString(),
                        currency: agreement.currency,
                        refId: referenceId,
                        autoRefundAt,
                    },
                }),
                this.notifySafely(agreement.receiver_id, 'security', 'ORBI PaySafe return requested', {
                    sw: `Mtumaji ameomba kurejesha PaySafe ${referenceId} ya ${formattedAmount}. Kubali return au fungua dispute ndani ya saa 24; ukikaa kimya fedha zitarudi kiotomatiki.`,
                    en: `The sender requested a return for ${formattedAmount} PaySafe ${referenceId}. Accept the return or open a dispute within 24 hours; no response will auto-return the funds.`,
                }, {
                    variables: {
                        amount: Number(agreement.amount).toLocaleString(),
                        currency: agreement.currency,
                        refId: referenceId,
                        autoRefundAt,
                    },
                }),
            ]);
            await Audit.log('FINANCIAL', actorId, 'ESCROW_RETURN_REQUESTED', {
                referenceId,
                senderId: agreement.sender_id,
                receiverId: agreement.receiver_id,
                transactionId: agreement.transaction_id,
                reason,
                autoRefundAt,
                idempotent: Boolean(result?.idempotent),
            });
            return result;
        }
        await Promise.all([
            this.notifySafely(agreement.sender_id, 'info', 'ORBI PaySafe payment refunded', {
                sw: `Malipo yako ya PaySafe ${referenceId} ya ${formattedAmount} yamerejeshwa kwenye akaunti yako.`,
                en: `Your ${formattedAmount} PaySafe payment ${referenceId} has been refunded to your account.`,
            }, {
                template: 'Escrow_Refunded',
                variables: {
                    amount: Number(agreement.amount).toLocaleString(),
                    currency: agreement.currency,
                    refId: referenceId,
                },
            }),
            this.notifySafely(agreement.receiver_id, 'info', 'ORBI PaySafe refund completed', {
                sw: `PaySafe ${referenceId} ya ${formattedAmount} imerejeshwa kwa mtumaji. Hold hii imefungwa.`,
                en: `PaySafe ${referenceId} for ${formattedAmount} was refunded to the sender. This hold is now closed.`,
            }, {
                template: 'Escrow_Refunded',
                variables: {
                    amount: Number(agreement.amount).toLocaleString(),
                    currency: agreement.currency,
                    refId: referenceId,
                },
            }),
        ]);
        await Audit.log('FINANCIAL', actorId, 'ESCROW_REFUNDED', {
            referenceId,
            senderId: agreement.sender_id,
            receiverId: agreement.receiver_id,
            transactionId: agreement.transaction_id,
            reason,
            idempotent: Boolean(result?.idempotent),
        });
        return result;
    }

    public async getEscrow(referenceId: string, actorId: string): Promise<Record<string, any> | null> {
        const agreement = await this.findAgreement(referenceId);
        if (!agreement) return null;
        if (![agreement.sender_id, agreement.receiver_id].includes(actorId)) {
            throw new Error('ESCROW_ACCESS_DENIED');
        }
        return this.decorateAgreement(agreement, actorId);
    }

    public async getEscrows(userId: string): Promise<Record<string, any>[]> {
        const sb = getAdminSupabase() || getSupabase();
        if (!sb) return [];
        const { data, error } = await sb
            .from('escrow_agreements')
            .select('*')
            .or(`sender_id.eq.${userId},receiver_id.eq.${userId}`)
            .order('created_at', { ascending: false });
        if (error) {
            this.logSupabaseError('escrow list query failed', error);
            throw new Error('PAYSAFE_ESCROW_QUERY_FAILED');
        }
        const agreements = await this.attachTransactions((data || []) as EscrowAgreementRecord[]);
        return agreements.map((agreement) =>
            this.decorateAgreement(agreement, userId),
        );
    }

    private async getAgreement(referenceId: string): Promise<EscrowAgreementRecord> {
        const agreement = await this.findAgreement(referenceId);
        if (!agreement) throw new Error('ESCROW_NOT_FOUND');
        return agreement;
    }

    private async findAgreement(referenceId: string): Promise<EscrowAgreementRecord | null> {
        const sb = getAdminSupabase() || getSupabase();
        if (!sb) throw new Error('VAULT_OFFLINE');
        const { data, error } = await sb
            .from('escrow_agreements')
            .select('*')
            .eq('reference_id', referenceId)
            .maybeSingle();
        if (error) {
            this.logSupabaseError('escrow detail query failed', error);
            throw new Error('PAYSAFE_ESCROW_QUERY_FAILED');
        }
        if (!data) return null;
        const [agreement] = await this.attachTransactions([data as EscrowAgreementRecord]);
        return agreement || null;
    }

    private async attachTransactions(agreements: EscrowAgreementRecord[]): Promise<EscrowAgreementRecord[]> {
        if (!agreements.length) return agreements;
        const sb = getAdminSupabase() || getSupabase();
        if (!sb) return agreements;

        const transactionIds = Array.from(new Set(
            agreements
                .map((agreement) => agreement.transaction_id)
                .filter((id): id is string => Boolean(id)),
        ));
        if (!transactionIds.length) return agreements;

        const { data, error } = await sb
            .from('transactions')
            .select('*')
            .in('id', transactionIds);
        if (error) {
            this.logSupabaseError('escrow transaction hydration failed', error);
            return agreements;
        }

        const transactionById = new Map(
            ((data || []) as Record<string, any>[]).map((transaction) => [String(transaction.id), transaction]),
        );
        return agreements.map((agreement) => ({
            ...agreement,
            transaction: transactionById.get(String(agreement.transaction_id)) || null,
        }));
    }

    private logSupabaseError(context: string, error: any): void {
        console.warn(`[PAYSAFE_LEDGER] ${context}`, {
            code: error?.code,
            message: error?.message,
            details: error?.details,
            hint: error?.hint,
        });
    }

    private async transition(
        referenceId: string,
        actorId: string,
        action: 'RELEASE' | 'ACCEPT' | 'DISPUTE' | 'REFUND',
        receiverVaultId: string | null = null,
        reason: string | null = null,
    ): Promise<Record<string, any>> {
        const sb = getAdminSupabase();
        if (!sb) throw new Error('SERVICE_ROLE_REQUIRED');
        const { data, error } = await sb.rpc('transition_paysafe_escrow_v1', {
            p_reference_id: referenceId,
            p_actor_id: actorId,
            p_action: action,
            p_receiver_vault_id: receiverVaultId,
            p_reason: reason,
        });
        if (error) {
            const domainError = String(error.message || '').match(/PAYSAFE_[A-Z0-9_]+(?::[^"]+)?/)?.[0];
            throw new Error(domainError || 'PAYSAFE_TRANSITION_FAILED');
        }
        return (data || {}) as Record<string, any>;
    }

    private resolveHoldWindowHours(conditions: Record<string, unknown>): number {
        const raw = conditions.holdWindowHours ?? conditions.hold_window_hours ?? 24;
        const parsed = Number(raw);
        if (!Number.isFinite(parsed)) return 24;
        return Math.min(Math.max(Math.round(parsed), 1), 168);
    }

    private isExpired(agreement: EscrowAgreementRecord): boolean {
        const expiresAt = agreement.expires_at ? new Date(agreement.expires_at) : null;
        return Boolean(expiresAt && Number.isFinite(expiresAt.getTime()) && expiresAt.getTime() < Date.now());
    }

    private decorateAgreement(agreement: EscrowAgreementRecord, actorId: string): Record<string, any> {
        const actorRole = agreement.sender_id === actorId ? 'sender' : 'receiver';
        const status = String(agreement.status || '').toUpperCase() as EscrowStatus;
        const expired = this.isExpired(agreement);
        const receiverAccepted = Boolean(agreement.receiver_accepted_at || agreement.receiver_accepted_by);
        const returnPending = status === 'RETURN_PENDING';
        const availableActions = {
            release: actorRole === 'sender' && status === 'HELD' && receiverAccepted && !expired,
            accept: actorRole === 'receiver' && (
                (status === 'HELD' && !receiverAccepted && !expired)
                || (status === 'RELEASE_PENDING' && !expired)
                || (returnPending && !expired)
            ),
            refund: actorRole === 'sender' && ['HELD', 'DISPUTED'].includes(status) && !expired,
            dispute: ['sender', 'receiver'].includes(actorRole) && ['HELD', 'RELEASE_PENDING', 'RETURN_PENDING'].includes(status),
        };
        return {
            ...agreement,
            actorRole,
            isSender: actorRole === 'sender',
            isReceiver: actorRole === 'receiver',
            awaitingReceiverAcceptance: (status === 'HELD' && !receiverAccepted) || status === 'RELEASE_PENDING',
            receiverAccepted,
            receiverAcceptanceRequired: true,
            returnPending,
            returnAutoRefundAt: returnPending
                ? String((agreement.metadata || {}).return_auto_refund_at || agreement.expires_at || '')
                : null,
            holdWindowExpired: expired,
            holdWindowEndsAt: agreement.expires_at || null,
            availableActions,
        };
    }

    private async settleMerchantEscrow(
        referenceId: string,
        actorId: string,
    ): Promise<Record<string, any>> {
        const sb = getAdminSupabase();
        if (!sb) throw new Error('SERVICE_ROLE_REQUIRED');
        const { data, error } = await sb.rpc('settle_merchant_paysafe_v1', {
            p_reference_id: referenceId,
            p_actor_id: actorId,
        });
        if (error) {
            const domainError = String(error.message || '').match(/PAYSAFE_[A-Z0-9_]+(?::[^"]+)?/)?.[0];
            throw new Error(domainError || 'PAYSAFE_MERCHANT_SETTLEMENT_FAILED');
        }
        return (data || {}) as Record<string, any>;
    }

    private async notifySafely(
        userId: string,
        type: 'info' | 'security',
        subject: string,
        body: { sw: string; en: string },
        options: Record<string, any> = {},
    ): Promise<void> {
        try {
            const sb = getAdminSupabase() || getSupabase();
            const { data: user } = sb
                ? await sb.from('users').select('language').eq('id', userId).maybeSingle()
                : { data: null };
            await Messaging.dispatch(
                userId,
                type,
                subject,
                user?.language === 'sw' ? body.sw : body.en,
                { push: true, sms: true, email: true, ...options },
            );
        } catch (error) {
            console.error('[EscrowService] Notification dispatch failed.', {
                userId,
                subject,
                error: error instanceof Error ? error.message : String(error),
            });
            // Notification delivery is a side effect and must not roll back a committed escrow action.
        }
    }
}
