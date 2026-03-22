import { 
    generateRegistrationOptions, 
    verifyRegistrationResponse, 
    generateAuthenticationOptions, 
    verifyAuthenticationResponse 
} from "@simplewebauthn/server";
import { getAdminSupabase } from "../../../supabaseClient.js";
import { normalizeAndroidOrigin, sameTrustedOrigin } from "../../../security/passkeyUtils.js";

const RP_NAME = "SecureBank";

export class PasskeyService {
    async generateRegistration(user: { id: string; email: string }, rpID: string) {
        return generateRegistrationOptions({
            rpName: RP_NAME,
            rpID: rpID,
            userID: new Uint8Array(Buffer.from(user.id)),
            userName: user.email,
            attestationType: 'none',
            authenticatorSelection: {
                residentKey: 'preferred',
                userVerification: 'preferred',
                authenticatorAttachment: 'platform',
            },
        });
    }

    async verifyRegistration(userId: string, response: any, expectedChallenge: string, expectedOrigin: string, expectedRPID: string) {
        console.log(`[PasskeyService] Verifying registration for user ${userId}:
            Expected_Origin=${expectedOrigin}
            Expected_RPID=${expectedRPID}
        `);
        
        try {
            const verification = await verifyRegistrationResponse({
                response,
                expectedChallenge,
                expectedOrigin,
                expectedRPID: expectedRPID,
                requireUserVerification: false,
            });

            // Manual origin check using sameTrustedOrigin
            if (!sameTrustedOrigin(verification.registrationInfo?.origin || "", expectedOrigin)) {
                throw new Error(`Unexpected registration response origin "${verification.registrationInfo?.origin}", expected "${expectedOrigin}"`);
            }

            console.log(`[PasskeyService] Registration verification result for ${userId}: ${verification.verified ? 'SUCCESS' : 'FAILED'}`);

            if (verification.verified && verification.registrationInfo) {
            const { credential } = verification.registrationInfo;
            const { publicKey, id, counter } = credential;
            
            const sb = getAdminSupabase();
            if (!sb) throw new Error("Database offline");

            // Enforce limit of 2 passkeys per user (Professional Security Standard)
            const { data: existingPasskeys } = await sb.from('passkeys')
                .select('id, created_at')
                .eq('user_id', userId)
                .order('created_at', { ascending: true });

            if (existingPasskeys && existingPasskeys.length >= 2) {
                // FIFO Replacement: Remove the oldest credential to make room for the new one
                const oldest = existingPasskeys[0];
                await sb.from('passkeys').delete().eq('id', oldest.id);
            }

            const { error } = await sb.from('passkeys').insert({
                user_id: userId,
                credential_id: id,
                public_key: Buffer.from(publicKey).toString('base64url'),
                counter: counter,
            });

            if (error) throw error;
        }

        return verification.verified;
        } catch (e: any) {
            console.error(`[PasskeyService] Registration verification error for user ${userId}:`, e);
            throw e;
        }
    }

    async generateLoginOptions(userId: string, rpID: string) {
        const sb = getAdminSupabase();
        if (!sb) throw new Error("Database offline");

        const { data: passkeys } = await sb.from('passkeys').select('*').eq('user_id', userId);
        
        return generateAuthenticationOptions({
            rpID: rpID,
            allowCredentials: passkeys?.map(p => ({
                id: p.credential_id,
                type: 'public-key',
            })),
            userVerification: 'preferred',
        });
    }

    async verifyLogin(userId: string, response: any, expectedChallenge: string, expectedOrigin: string, expectedRPID: string) {
        console.log(`[PasskeyService] Verifying login for user ${userId}:
            Expected_Origin=${expectedOrigin}
            Expected_RPID=${expectedRPID}
            Credential_ID=${response.id}
        `);

        const sb = getAdminSupabase();
        if (!sb) throw new Error("Database offline");

        const { data: passkey } = await sb.from('passkeys')
            .select('*')
            .eq('user_id', userId)
            .eq('credential_id', response.id)
            .single();

        if (!passkey) {
            console.error(`[PasskeyService] Passkey not found for user ${userId} and credential ${response.id}`);
            throw new Error("Passkey not found");
        }

        try {
            const verification = await verifyAuthenticationResponse({
                response,
                expectedChallenge,
                expectedOrigin,
                expectedRPID: expectedRPID,
                credential: {
                    id: passkey.credential_id,
                    publicKey: Buffer.from(passkey.public_key, 'base64url'),
                    counter: passkey.counter,
                },
            });

            // Manual origin check using sameTrustedOrigin
            if (!sameTrustedOrigin(verification.authenticationInfo.origin, expectedOrigin)) {
                throw new Error(`Unexpected authentication response origin "${verification.authenticationInfo.origin}", expected "${expectedOrigin}"`);
            }

            console.log(`[PasskeyService] Login verification result for ${userId}: ${verification.verified ? 'SUCCESS' : 'FAILED'}`);

            if (verification.verified) {
            // Update counter
            await sb.from('passkeys')
                .update({ 
                    counter: verification.authenticationInfo.newCounter,
                    last_used_at: new Date().toISOString()
                })
                .eq('id', passkey.id);
        }

        return verification.verified;
        } catch (e: any) {
            console.error(`[PasskeyService] Login verification error for user ${userId}:`, e);
            throw e;
        }
    }
}

export const Passkeys = new PasskeyService();
