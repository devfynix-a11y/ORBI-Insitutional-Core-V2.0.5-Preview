
import { UUID } from '../../services/utils.js';
import { RedisManager } from '../enterprise/infrastructure/RedisManager.js';
import { RedisClusterFactory } from '../infrastructure/RedisClusterFactory.js';
import { getAdminSupabase } from '../../services/supabaseClient.js';
import { orbiGatewayService } from '../infrastructure/orbiGatewayService.js';
import parsePhoneNumber from 'libphonenumber-js';

interface OTPRecord {
    code: string;
    expiresAt: number;
    userId: string;
    action: string;
}

export class OTPService {
    private static PREFIX = 'otp:';
    private static THROTTLE_PREFIX = 'otp_throttle:';

    /**
     * Generate and send a new OTP for a specific action
     */
    static async generateAndSend(userId: string, contact: string, action: string, type: 'sms' | 'email' | 'push' | 'whatsapp' = 'sms', deviceName?: string): Promise<{ requestId: string, code?: string, deliveryType?: string, deliveryContact?: string }> {
        // 1. Throttling check (60 seconds)
        const throttleKey = this.THROTTLE_PREFIX + userId + ':' + action;
        const isThrottled = await RedisManager.get(throttleKey);
        if (isThrottled) {
            console.warn(`[OTPService] Throttling active for ${userId} on ${action}`);
            return { requestId: 'THROTTLED' };
        }

        // Validation
        if (!contact) {
            console.error(`[OTPService] Cannot send OTP for ${action}: No contact provided for user ${userId}`);
            return { requestId: 'ERROR_NO_CONTACT' };
        }

        // Generate a 6-digit code
        const code = Math.floor(100000 + Math.random() * 900000).toString();
        const requestId = UUID.generate();
        
        const record: OTPRecord = {
            code,
            expiresAt: Date.now() + 5 * 60 * 1000, // 5 minutes expiry
            userId,
            action
        };

        // Store in Redis (5 minutes TTL)
        await RedisManager.set(this.PREFIX + requestId, record, 300);
        // Set throttle (60 seconds)
        await RedisManager.set(throttleKey, 'active', 60);

        // Fallback: Store in Database if Redis is not available
        if (!RedisClusterFactory.isAvailable()) {
            await this.saveToDB(userId, requestId, record);
        }

        let actualType = type;
        let actualContact = contact;

        // Send via Provider
        try {
            let language = 'en';
            let fcmToken = '';
            let country = '';
            let phone = '';
            let email = '';
            let name = '';
            let isTanzania = false;
            const sb = getAdminSupabase();
            if (sb) {
                let profile: any = null;
                
                if (userId && userId !== 'system') {
                    const { data: userProfile } = await sb.from('users').select('name, language, fcm_token, nationality, phone, email, id_type').eq('id', userId).maybeSingle();
                    profile = userProfile;
                    
                    if (!profile) {
                        const { data: staffProfile } = await sb.from('staff').select('name, language, fcm_token, nationality, phone, email, id_type').eq('id', userId).maybeSingle();
                        profile = staffProfile;
                    }
                } else if (contact) {
                    if (contact.includes('@')) {
                        const { data: userProfile } = await sb.from('users').select('name, language, fcm_token, nationality, phone, email, id_type').eq('email', contact).maybeSingle();
                        profile = userProfile;
                        if (!profile) {
                            const { data: staffProfile } = await sb.from('staff').select('name, language, fcm_token, nationality, phone, email, id_type').eq('email', contact).maybeSingle();
                            profile = staffProfile;
                        }
                    } else {
                        const { data: userProfile } = await sb.from('users').select('name, language, fcm_token, nationality, phone, email, id_type').eq('phone', contact).maybeSingle();
                        profile = userProfile;
                        if (!profile) {
                            const { data: staffProfile } = await sb.from('staff').select('name, language, fcm_token, nationality, phone, email, id_type').eq('phone', contact).maybeSingle();
                            profile = staffProfile;
                        }
                    }
                }

                if (profile) {
                    language = profile.language || 'en';
                    fcmToken = profile.fcm_token || '';
                    country = profile.nationality || 'Tanzania';
                    phone = profile.phone || '';
                    email = profile.email || '';
                    name = profile.name || 'User';
                }

                if (!phone && userId && userId !== 'system') {
                    const { data: authData } = await sb.auth.admin.getUserById(userId);
                    phone = authData.user?.phone || authData.user?.user_metadata?.phone || '';
                }

                isTanzania = country.toLowerCase().includes('tanzania') || 
                                   country.toLowerCase().includes('tz') || 
                                   (phone && phone.startsWith('+255')) ||
                                   (profile?.id_type === 'NIDA');

                const bestPhone = phone || (contact && !contact.includes('@') ? contact : '');
                const bestEmail = email || (contact && contact.includes('@') ? contact : '');

                // User Request: Refined channel selection based on user origin and identity
                // Tanzania -> SMS/Push. Others -> Email/WhatsApp/Push.
                if (isTanzania) {
                    if (bestPhone) {
                        actualType = 'sms';
                        actualContact = bestPhone;
                    } else if (fcmToken) {
                        actualType = 'push';
                        actualContact = fcmToken;
                    } else if (bestEmail) {
                        actualType = 'email';
                        actualContact = bestEmail;
                    }
                } else {
                    // Non-Tanzania: Email > WhatsApp > Push > SMS
                    if (bestEmail) {
                        actualType = 'email';
                        actualContact = bestEmail;
                    } else if (bestPhone) {
                        actualType = 'whatsapp';
                        actualContact = bestPhone;
                    } else if (fcmToken) {
                        actualType = 'push';
                        actualContact = fcmToken;
                    } else if (bestPhone) {
                        actualType = 'sms';
                        actualContact = bestPhone;
                    }
                }
            }

            // Format phone if applicable
            if ((actualType === 'sms' || actualType === 'whatsapp') && actualContact) {
                try {
                    let region: any = 'TZ';
                    if (country && country.length === 2) {
                        region = country.toUpperCase();
                    } else if (isTanzania) {
                        region = 'TZ';
                    }
                    const parsed = parsePhoneNumber(actualContact, region);
                    actualContact = parsed ? parsed.format('E.164') : (actualContact.startsWith('+') ? actualContact : '+' + actualContact.replace(/\s/g, ''));
                } catch (e) {
                    actualContact = actualContact.startsWith('+') ? actualContact : '+' + actualContact.replace(/\s/g, '');
                }
            }

            console.log(`[OTPService] Generating OTP for ${action} (User: ${userId}, Contact: ${actualContact}, Type: ${actualType})`);

            const ANDROID_HASH = process.env.ORBI_ANDROID_SMS_HASH;

            if (actualType === 'sms') {
                console.log(`[OTPService] Sending SMS OTP to ${actualContact}`);
                await orbiGatewayService.sendTemplate('OTP_Message', actualContact, { 
                    otp: code, 
                    name: name,
                    deviceName: deviceName || 'Unknown Device',
                    androidHash: ANDROID_HASH 
                }, { messageType: 'transactional', language, fcmToken, channel: 'sms', requestId });
            } else if (actualType === 'whatsapp') {
                console.log(`[OTPService] Sending WhatsApp OTP to ${actualContact}`);
                await orbiGatewayService.sendTemplate('OTP_Message', actualContact, { 
                    otp: code, 
                    name: name,
                    deviceName: deviceName || 'Unknown Device',
                    androidHash: ANDROID_HASH 
                }, { messageType: 'transactional', language, fcmToken, channel: 'whatsapp', requestId });
            } else if (actualType === 'email') {
                console.log(`[OTPService] Sending Email OTP to ${actualContact}`);
                await orbiGatewayService.sendTemplate('OTP_Message', actualContact, { 
                    otp: code, 
                    name: name,
                    deviceName: deviceName || 'Unknown Device',
                    androidHash: ANDROID_HASH 
                }, { messageType: 'transactional', language, fcmToken, channel: 'email', requestId });
            } else if (actualType === 'push' && fcmToken) {
                console.log(`[OTPService] Sending Push OTP to ${actualContact}`);
                await orbiGatewayService.sendTemplate('OTP_Message', fcmToken, { 
                    otp: code, 
                    name: name,
                    deviceName: deviceName || 'Unknown Device',
                    androidHash: ANDROID_HASH 
                }, { messageType: 'transactional', language, fcmToken, channel: 'push', requestId });
            }
            
            console.info(`[OTPService] OTP Code ${code} generated for ${userId}. Delivery type ${actualType} handled via orbiGatewayService.`);
        } catch (error) {
            console.error(`[OTPService] Fault during dispatch:`, error);
        }

        return { requestId, code, deliveryType: actualType, deliveryContact: actualContact };
    }

    /**
     * Verify an OTP code
     */
    static async verify(requestId: string, code: string, userId: string): Promise<boolean> {
        const key = this.PREFIX + requestId;
        let record: OTPRecord | null = await RedisManager.get(key) as OTPRecord;
        
        // Fallback: Check Database if not found in Redis
        if (!record && !RedisClusterFactory.isAvailable()) {
            record = await this.getFromDB(userId, requestId);
        }

        if (!record) {
            console.warn(`[OTPService] Verification failed: No record found for key ${key} (User: ${userId})`);
            return false;
        }

        if (record.userId !== userId) {
            console.warn(`[OTPService] Verification failed: User ID mismatch. Expected ${record.userId}, got ${userId}`);
            return false;
        }

        if (record.expiresAt < Date.now()) {
            console.warn(`[OTPService] Verification failed: OTP expired for key ${key}`);
            await RedisManager.delete(key);
            await this.removeFromDB(userId, requestId);
            return false;
        }

        if (record.code === code) {
            console.log(`[OTPService] Verification successful for key ${key}`);
            await RedisManager.delete(key);
            await this.removeFromDB(userId, requestId);
            return true;
        }

        console.warn(`[OTPService] Verification failed: Code mismatch for key ${key}. Expected ${record.code}, got ${code}`);
        return false;
    }

    /**
     * Database Fallback Helpers
     */
    private static async saveToDB(userId: string, requestId: string, record: OTPRecord) {
        try {
            const sb = getAdminSupabase();
            if (!sb) return;

            const { data } = await sb.auth.admin.getUserById(userId);
            const metadata = data.user?.user_metadata || {};
            const otps = metadata.active_otps || {};
            
            // Clean up expired ones while we're at it
            const now = Date.now();
            const cleanedOtps: any = {};
            for (const [id, rec] of Object.entries(otps)) {
                if ((rec as any).expiresAt > now) {
                    cleanedOtps[id] = rec;
                }
            }

            cleanedOtps[requestId] = record;

            await sb.auth.admin.updateUserById(userId, {
                user_metadata: { ...metadata, active_otps: cleanedOtps }
            });
        } catch (e) {
            console.error('[OTPService] DB Save Fallback Failed:', e);
        }
    }

    private static async getFromDB(userId: string, requestId: string): Promise<OTPRecord | null> {
        try {
            const sb = getAdminSupabase();
            if (!sb) return null;

            const { data } = await sb.auth.admin.getUserById(userId);
            const otps = data.user?.user_metadata?.active_otps || {};
            return otps[requestId] || null;
        } catch (e) {
            console.error('[OTPService] DB Get Fallback Failed:', e);
            return null;
        }
    }

    private static async removeFromDB(userId: string, requestId: string) {
        try {
            const sb = getAdminSupabase();
            if (!sb) return;

            const { data } = await sb.auth.admin.getUserById(userId);
            const metadata = data.user?.user_metadata || {};
            const otps = { ...(metadata.active_otps || {}) };
            
            if (otps[requestId]) {
                delete otps[requestId];
                await sb.auth.admin.updateUserById(userId, {
                    user_metadata: { ...metadata, active_otps: otps }
                });
            }
        } catch (e) {
            console.error('[OTPService] DB Remove Fallback Failed:', e);
        }
    }

    /**
     * Cleanup expired OTPs (Handled by Redis TTL, but kept for interface compatibility)
     */
    static cleanup() {
        // Redis handles this automatically via TTL
    }
}
