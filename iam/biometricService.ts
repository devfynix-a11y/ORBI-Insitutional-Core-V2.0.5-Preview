import { 
    generateRegistrationOptions, 
    verifyRegistrationResponse, 
    generateAuthenticationOptions, 
    verifyAuthenticationResponse 
} from '@simplewebauthn/server';
import { AuthenticatorTransportFuture, RegistrationResponseJSON, AuthenticationResponseJSON } from '@simplewebauthn/types';
import { getSupabase, getAdminSupabase } from '../services/supabaseClient.js';
import { Storage, STORAGE_KEYS } from '../backend/storage.js';
import { AuthService } from './authService.js';
import { OTPService } from '../backend/security/otpService.js';

// Configuration
// Default to the known Cloud Run domain if env vars are missing
const DEFAULT_HOST = 'orbi-financial-technologies-c0re-v2026.onrender.com';
const RP_NAME = 'ORBI Sovereign Bank';
const RP_ID = process.env.RP_ID || DEFAULT_HOST;
const ORIGIN = process.env.ORIGIN || `https://${DEFAULT_HOST}`;

export interface Authenticator {
    credentialID: string;
    credentialPublicKey: string;
    counter: number;
    transports?: AuthenticatorTransportFuture[];
}

export class BiometricService {
    private authService = new AuthService();

    /**
     * Step 1: Start Registration
     * Generates options for the client to create a new credential (Passkey).
     * Enforces Single Device Policy: If a device is already registered, requires OTP to replace it.
     */
    async registerStart(userId: string, otpCode?: string, otpRequestId?: string, deviceName: string = 'Unknown Device', rpID: string = RP_ID, origin: string = ORIGIN) {
        console.log(`[BiometricService] registerStart initiated for user ${userId} on device ${deviceName}`);
        console.log(`[BiometricService] Params - otpCode: "${otpCode}", otpRequestId: "${otpRequestId}"`);

        const sb = getAdminSupabase();
        let user: any;
        let authenticators: Authenticator[] = [];

        if (sb) {
            const { data, error } = await sb.auth.admin.getUserById(userId);
            if (error || !data.user) throw new Error("User not found in Cloud Auth");
            user = data.user;
            authenticators = (user?.user_metadata?.authenticators || []).filter((a: any) => a && a.credentialID);
        } else {
            // Local Fallback
            const users = Storage.getFromDB<any>(STORAGE_KEYS.CUSTOM_USERS);
            user = users.find(u => u.id === userId);
            authenticators = (user?.authenticators || []).filter((a: any) => a && a.credentialID);
        }

        if (!user) throw new Error("User not found");

        console.log(`[BiometricService] User found. Valid authenticators count: ${authenticators.length}`);

        // DUAL DEVICE POLICY CHECK (Professional Security Standard)
        if (authenticators.length > 0) {
            // Device(s) already registered. Check for OTP to authorize adding/replacing.
            const cleanCode = typeof otpCode === 'string' ? otpCode.trim() : undefined;
            const cleanId = typeof otpRequestId === 'string' ? otpRequestId.trim() : undefined;
            
            const isOtpMissing = !cleanCode || !cleanId || 
                                cleanCode === 'null' || cleanId === 'null' || 
                                cleanCode === 'undefined' || cleanId === 'undefined' ||
                                cleanCode === '' || cleanId === '';

            if (isOtpMissing) {
                // Generate OTP
                const contact = user.email || user.phone || user.user_metadata?.phone;
                
                if (!contact) throw new Error("Contact method (email or phone) required for device verification");
                
                const type = contact.includes('@') ? 'email' : 'sms';
                const { requestId, deliveryType } = await OTPService.generateAndSend(userId, contact, 'DEVICE_CHANGE', type as any, deviceName);
                
                const action = authenticators.length >= 2 ? 'replacing your oldest device' : 'adding a backup device';
                return { 
                    status: 'CHALLENGE_REQUIRED', 
                    challengeType: 'OTP', 
                    requestId,
                    message: `Security verification required. OTP sent via ${deliveryType || type} to verify ${action}.` 
                };
            }

            // Verify OTP
            const isValid = await OTPService.verify(cleanId!, cleanCode!, userId);
            if (!isValid) {
                throw new Error("Invalid or expired OTP");
            }
        }

        const options = await generateRegistrationOptions({
            rpName: RP_NAME,
            rpID: rpID,
            userID: new Uint8Array(Buffer.from(userId)),
            userName: user.email || user.phone || 'Customer',
            userDisplayName: user.user_metadata?.full_name || user.email || user.phone || 'Customer',
            // We DO NOT exclude credentials here because we are replacing the old one
            // excludeCredentials: authenticators.map(auth => ({ ... })), 
            authenticatorSelection: {
                residentKey: 'preferred',
                userVerification: 'preferred',
                authenticatorAttachment: 'platform', // Force platform authenticator (TouchID/FaceID)
            },
        });

        // Store challenge temporarily (in DB or cache)
        await this.saveChallenge(userId, options.challenge);

        return { status: 'OK', options };
    }

    /**
     * Step 2: Finish Registration
     * Verifies the client response and stores the new credential.
     * REPLACES any existing authenticator to enforce Single Device Policy.
     */
    async registerFinish(userId: string, response: RegistrationResponseJSON, rpID: string = RP_ID, origin: string = ORIGIN) {
        const challenge = await this.getChallenge(userId);
        if (!challenge) throw new Error("Challenge expired or not found");

        const clientData = JSON.parse(Buffer.from(response.response.clientDataJSON, 'base64url').toString('utf-8'));
        const clientOrigin = clientData.origin;
        
        let allowedOrigins = [origin];
        if (clientOrigin.startsWith('android:apk-key-hash:') || clientOrigin.startsWith('http://localhost')) {
            allowedOrigins.push(clientOrigin);
        }

        const verification = await verifyRegistrationResponse({
            response,
            expectedChallenge: challenge,
            expectedOrigin: allowedOrigins,
            expectedRPID: rpID,
        });

        if (verification.verified && verification.registrationInfo) {
            const info = verification.registrationInfo as any;
            const credentialPublicKey = info.credentialPublicKey || info.credential?.publicKey;
            const credentialID = info.credentialID || info.credential?.id;
            const counter = info.counter || info.credential?.counter;

            const newAuthenticator: Authenticator = {
                credentialID: typeof credentialID === 'string' ? credentialID : Buffer.from(credentialID).toString('base64url'),
                credentialPublicKey: Buffer.from(credentialPublicKey).toString('base64url'),
                counter,
                transports: response.response.transports as AuthenticatorTransportFuture[],
            };

            // OVERWRITE existing authenticators (Single Device Policy)
            await this.saveAuthenticator(userId, newAuthenticator, true);
            await this.clearChallenge(userId);

            return { success: true };
        }

        throw new Error("Verification failed");
    }


    /**
     * Step 3: Start Login
     * Generates options for the client to authenticate with an existing credential.
     */
    async loginStart(userId: string, rpID: string = RP_ID, origin: string = ORIGIN) {
        const authenticators = await this.getUserAuthenticators(userId);
        if (authenticators.length === 0) throw new Error("No biometrics registered");

        const options = await generateAuthenticationOptions({
            rpID: rpID,
            allowCredentials: authenticators.map(auth => ({
                id: auth.credentialID as any,
                type: 'public-key',
                transports: auth.transports,
            })),
            userVerification: 'preferred',
        });

        await this.saveChallenge(userId, options.challenge);

        return options;
    }

    /**
     * Step 4: Finish Login
     * Verifies the client response and returns a session.
     */
    async loginFinish(userId: string, response: AuthenticationResponseJSON, rpID: string = RP_ID, origin: string = ORIGIN) {
        const challenge = await this.getChallenge(userId);
        if (!challenge) throw new Error("Challenge expired or not found");

        const authenticators = await this.getUserAuthenticators(userId);
        const authenticator = authenticators.find(auth => auth.credentialID === response.id);

        if (!authenticator) throw new Error("Authenticator not found");

        const clientData = JSON.parse(Buffer.from(response.response.clientDataJSON, 'base64url').toString('utf-8'));
        const clientOrigin = clientData.origin;
        
        let allowedOrigins = [origin];
        if (clientOrigin.startsWith('android:apk-key-hash:') || clientOrigin.startsWith('http://localhost')) {
            allowedOrigins.push(clientOrigin);
        }

        const verification = await verifyAuthenticationResponse({
            response,
            expectedChallenge: challenge,
            expectedOrigin: allowedOrigins,
            expectedRPID: rpID,
            credential: {
                id: authenticator.credentialID,
                publicKey: Buffer.from(authenticator.credentialPublicKey, 'base64url'),
                counter: authenticator.counter,
            },
        } as any);

        if (verification.verified) {
            const { authenticationInfo } = verification;
            
            // Update counter
            authenticator.counter = authenticationInfo.newCounter;
            await this.updateAuthenticator(userId, authenticator);
            await this.clearChallenge(userId);

            // Generate Session
            const session = await this.authService.generateSessionForUser(userId);
            if (!session) throw new Error("Session generation failed");

            return { success: true, verified: true, session };
        }

        throw new Error("Verification failed");
    }

    // --- Helpers ---

    private async getUserAuthenticators(userId: string): Promise<Authenticator[]> {
        const sb = getAdminSupabase();
        if (sb) {
            const { data } = await sb.auth.admin.getUserById(userId);
            return data.user?.user_metadata?.authenticators || [];
        }
        const users = Storage.getFromDB<any>(STORAGE_KEYS.CUSTOM_USERS);
        const user = users.find(u => u.id === userId);
        return user?.authenticators || [];
    }

    private async saveAuthenticator(userId: string, authenticator: Authenticator, overwrite: boolean = false) {
        const sb = getAdminSupabase();
        if (sb) {
            const { data } = await sb.auth.admin.getUserById(userId);
            const currentMetadata = data.user?.user_metadata || {};
            let authenticators = currentMetadata.authenticators || [];
            
            // DUAL DEVICE POLICY: Limit to 2 authenticators
            if (authenticators.length >= 2) {
                // Replace oldest (FIFO)
                authenticators.shift();
            }
            authenticators.push(authenticator);
            
            await sb.auth.admin.updateUserById(userId, { 
                user_metadata: { ...currentMetadata, authenticators } 
            });
        } else {
            const users = Storage.getFromDB<any>(STORAGE_KEYS.CUSTOM_USERS);
            const idx = users.findIndex(u => u.id === userId);
            if (idx >= 0) {
                users[idx].authenticators = users[idx].authenticators || [];
                if (users[idx].authenticators.length >= 2) {
                    // Replace oldest (FIFO)
                    users[idx].authenticators.shift();
                }
                users[idx].authenticators.push(authenticator);
                Storage.saveToDB(STORAGE_KEYS.CUSTOM_USERS, users);
            }
        }
    }

    private async updateAuthenticator(userId: string, authenticator: Authenticator) {
        const sb = getAdminSupabase();
        if (sb) {
            const { data } = await sb.auth.admin.getUserById(userId);
            const currentMetadata = data.user?.user_metadata || {};
            const authenticators = currentMetadata.authenticators || [];
            const idx = authenticators.findIndex((a: any) => a.credentialID === authenticator.credentialID);
            if (idx >= 0) {
                authenticators[idx] = authenticator;
                await sb.auth.admin.updateUserById(userId, { 
                    user_metadata: { ...currentMetadata, authenticators } 
                });
            }
        } else {
            const users = Storage.getFromDB<any>(STORAGE_KEYS.CUSTOM_USERS);
            const idx = users.findIndex(u => u.id === userId);
            if (idx >= 0) {
                const authIdx = users[idx].authenticators.findIndex((a: any) => a.credentialID === authenticator.credentialID);
                if (authIdx >= 0) users[idx].authenticators[authIdx] = authenticator;
                Storage.saveToDB(STORAGE_KEYS.CUSTOM_USERS, users);
            }
        }
    }

    private async saveChallenge(userId: string, challenge: string) {
        const sb = getAdminSupabase();
        if (sb) {
            const { data } = await sb.auth.admin.getUserById(userId);
            const currentMetadata = data.user?.user_metadata || {};
            await sb.auth.admin.updateUserById(userId, { 
                user_metadata: { ...currentMetadata, currentChallenge: challenge } 
            });
        } else {
            const users = Storage.getFromDB<any>(STORAGE_KEYS.CUSTOM_USERS);
            const idx = users.findIndex(u => u.id === userId);
            if (idx >= 0) {
                users[idx].currentChallenge = challenge;
                Storage.saveToDB(STORAGE_KEYS.CUSTOM_USERS, users);
            }
        }
    }

    private async getChallenge(userId: string): Promise<string | null> {
        const sb = getAdminSupabase();
        if (sb) {
            const { data } = await sb.auth.admin.getUserById(userId);
            return data.user?.user_metadata?.currentChallenge || null;
        }
        const users = Storage.getFromDB<any>(STORAGE_KEYS.CUSTOM_USERS);
        const user = users.find(u => u.id === userId);
        return user?.currentChallenge || null;
    }

    private async clearChallenge(userId: string) {
        const sb = getAdminSupabase();
        if (sb) {
            const { data } = await sb.auth.admin.getUserById(userId);
            const currentMetadata = data.user?.user_metadata || {};
            const newMetadata = { ...currentMetadata };
            delete newMetadata.currentChallenge;
            await sb.auth.admin.updateUserById(userId, { user_metadata: newMetadata });
        } else {
            const users = Storage.getFromDB<any>(STORAGE_KEYS.CUSTOM_USERS);
            const idx = users.findIndex(u => u.id === userId);
            if (idx >= 0) {
                delete users[idx].currentChallenge;
                Storage.saveToDB(STORAGE_KEYS.CUSTOM_USERS, users);
            }
        }
    }
}

export const Biometrics = new BiometricService();
