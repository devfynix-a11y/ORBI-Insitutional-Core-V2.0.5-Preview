import { Request, Response } from 'express';
import { EntProcessor } from '../enterprise/wealth/EnterprisePaymentProcessor.js';
import { getSupabase, getAdminSupabase } from '../supabaseClient.js';
import { ProvisioningService } from '../features/ProvisioningService.js';

export class SandboxController {
    
    /**
     * FUND WALLET (SANDBOX ONLY)
     * Simulates an external deposit into a user's wallet.
     */
    static async fundWallet(req: Request, res: Response) {
        const { userId, walletId, amount, currency = 'USD' } = req.body;

        if (!userId || !amount) {
            return res.status(400).json({ success: false, error: 'MISSING_PARAMS: userId and amount are required.' });
        }

        try {
            // If walletId is not provided, resolve the user's operating wallet
            let targetWalletId = walletId;
            const adminSb = getAdminSupabase();
            
            if (!targetWalletId) {
                if (!adminSb) {
                    console.error("[Sandbox] Admin Supabase client not available. Check SUPABASE_SERVICE_ROLE_KEY.");
                    return res.status(500).json({ 
                        success: false, 
                        error: 'INFRASTRUCTURE_ERROR: Admin client missing. Cannot resolve or provision wallets.' 
                    });
                }

                // Verify user exists in Auth
                const { data: authUser, error: authError } = await adminSb.auth.admin.getUserById(userId);
                if (authError || !authUser.user) {
                    console.error(`[Sandbox] User ${userId} not found in Auth system: ${authError?.message || 'No user data'}`);
                    return res.status(404).json({ 
                        success: false, 
                        error: `USER_NOT_FOUND: The user ID ${userId} does not exist in the authentication system.` 
                    });
                }

                console.info(`[Sandbox] Resolving OPERATING wallet for userId: ${userId}`);
                const { data, error: fetchError } = await adminSb.from('platform_vaults')
                    .select('id, name')
                    .eq('user_id', userId)
                    .eq('vault_role', 'OPERATING')
                    .maybeSingle();
                
                if (fetchError) {
                    console.error(`[Sandbox] DB Error fetching wallet: ${fetchError.message}`);
                }

                if (data) {
                    targetWalletId = data.id;
                    console.info(`[Sandbox] Resolved wallet ${targetWalletId} (${data.name}) for user ${userId}`);
                } else {
                    // If not found, user might not be provisioned. Try provisioning now.
                    console.info(`[Sandbox] Wallet not found for ${userId}. Attempting auto-provisioning...`);
                    
                    // Fetch user info for provisioning
                    const { data: user, error: userError } = await adminSb.from('users').select('full_name').eq('id', userId).maybeSingle();
                    if (userError) console.warn(`[Sandbox] Could not fetch user profile: ${userError.message}`);
                    
                    const provisionResult = await ProvisioningService.provisionUser(userId, user?.full_name || 'Sandbox User');
                    console.info(`[Sandbox] Provisioning result for ${userId}: ${provisionResult.status}`);
                    
                    if (provisionResult.status === 'ready') {
                        // Try resolving again
                        const { data: retryData } = await adminSb.from('platform_vaults')
                            .select('id')
                            .eq('user_id', userId)
                            .eq('vault_role', 'OPERATING')
                            .maybeSingle();
                        if (retryData) {
                            targetWalletId = retryData.id;
                            console.info(`[Sandbox] Resolved wallet ${targetWalletId} after provisioning for user ${userId}`);
                        } else {
                            console.error(`[Sandbox] Wallet STILL not found for ${userId} after successful provisioning.`);
                        }
                    } else {
                        console.error(`[Sandbox] Provisioning failed for ${userId}: ${provisionResult.error}`);
                    }
                }
            }

            if (!targetWalletId) {
                return res.status(404).json({ success: false, error: 'WALLET_NOT_FOUND: Could not resolve target wallet.' });
            }

            // Fetch full user profile to satisfy Neural Sentinel checks
            let userProfile: any = { id: userId, user_metadata: { account_status: 'active' } }; // Default fallback

            if (adminSb) {
                const { data: user } = await adminSb.from('users').select('*').eq('id', userId).single();
                if (user) {
                    userProfile = {
                        id: user.id,
                        email: user.email,
                        phone: user.phone,
                        user_metadata: {
                            ...user,
                            account_status: user.account_status || 'active'
                        }
                    };
                }
            }

            const result = await EntProcessor.process(userProfile, {
                idempotencyKey: `SANDBOX-${Date.now()}`,
                sourceWalletId: '00000000-0000-0000-0000-000000000002', // Fixed Sandbox Faucet Wallet ID
                targetWalletId: targetWalletId,
                amount: Number(amount),
                currency,
                description: 'Sandbox Faucet Funding',
                type: 'DEPOSIT',
                metadata: { source: 'sandbox_faucet' }
            } as any);

            if (!result.success) {
                return res.status(400).json(result);
            }

            res.json({ success: true, data: result, message: `Successfully funded wallet with ${amount} ${currency}` });

        } catch (e: any) {
            console.error(`[Sandbox] Funding Failed: ${e.message}`);
            res.status(500).json({ success: false, error: e.message });
        }
    }

    /**
     * ACTIVATE USER (SANDBOX ONLY)
     * Sets the user's account status to 'active' to bypass ID-001.
     */
    static async activateUser(req: Request, res: Response) {
        const { userId } = req.body;
        if (!userId) return res.status(400).json({ success: false, error: 'MISSING_PARAMS: userId is required.' });

        const sb = getSupabase();
        if (!sb) return res.status(500).json({ error: 'DB_OFFLINE' });

        try {
            // Update Auth Metadata
            const { error: authError } = await sb.auth.admin.updateUserById(userId, {
                user_metadata: { account_status: 'active' }
            });

            if (authError) throw authError;

            // Update Public Table
            await sb.from('users').update({ account_status: 'active' }).eq('id', userId);

            res.json({ success: true, message: `User ${userId} activated for sandbox testing.` });
        } catch (e: any) {
            res.status(500).json({ success: false, error: e.message });
        }
    }
}
