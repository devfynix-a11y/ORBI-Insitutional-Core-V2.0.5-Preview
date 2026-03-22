import { getSupabase, getAdminSupabase } from '../services/supabaseClient.js';
import { Storage, STORAGE_KEYS } from '../backend/storage.js';
import { KYCRequest } from '../types.js';
import { UUID } from '../services/utils.js';
import { Messaging } from '../backend/features/MessagingService.js';
import { GoogleGenAI, Type } from "@google/genai";

export class KYCService {
    
    /**
     * Upload a document to Supabase Storage.
     */
    static async uploadDocument(userId: string, file: Buffer, fileName: string, contentType: string) {
        const sb = getAdminSupabase();
        if (!sb) throw new Error("Database connection unavailable");

        const bucket = process.env.KYC_BUCKET || 'kyc-documents';
        const filePath = `${userId}/${Date.now()}_${fileName}`;

        const { error: uploadError } = await sb.storage.from(bucket).upload(filePath, file, {
            contentType,
            upsert: true
        });

        if (uploadError) throw new Error(`UPLOAD_FAILED: ${uploadError.message}`);

        const { data } = sb.storage.from(bucket).getPublicUrl(filePath);
        return data.publicUrl;
    }

    /**
     * KYC Auto-Scan Machine (Neural OCR)
     * Uses Gemini to extract identity information from an image.
     */
    static async scanKYC(imageBuffer: Buffer, mimeType: string) {
        const apiKey = process.env.GEMINI_API_KEY;
        if (!apiKey) throw new Error("GEMINI_API_KEY_MISSING");

        const ai = new GoogleGenAI({ apiKey });
        const model = "gemini-2.5-flash";

        const prompt = `
            Analyze this identity document (ID card or Passport) and extract the following details.
            Ensure the ID Type is strictly one of: NATIONAL_ID, PASSPORT, DRIVER_LICENSE, or VOTER_ID.
            Dates must be in YYYY-MM-DD format.
        `;

        try {
            const response = await ai.models.generateContent({
                model,
                contents: [{
                    parts: [
                        { text: prompt },
                        { inlineData: { data: imageBuffer.toString('base64'), mimeType } }
                    ]
                }],
                config: {
                    responseMimeType: "application/json",
                    responseSchema: {
                        type: Type.OBJECT,
                        properties: {
                            full_name: { type: Type.STRING, description: "Full name on the document" },
                            id_number: { type: Type.STRING, description: "Identification number" },
                            id_type: { 
                                type: Type.STRING, 
                                description: "Type of ID",
                                enum: ["NATIONAL_ID", "PASSPORT", "DRIVER_LICENSE", "VOTER_ID"]
                            },
                            dob: { type: Type.STRING, description: "Date of birth in YYYY-MM-DD" },
                            expiry_date: { type: Type.STRING, description: "Expiry date in YYYY-MM-DD" },
                            nationality: { type: Type.STRING, description: "Nationality or country of issue" }
                        },
                        required: ["full_name", "id_number", "id_type"]
                    }
                }
            });

            const text = response.text;
            if (!text) throw new Error("AI_SCAN_FAILED: No data extracted from document.");
            
            // Clean the response text in case of markdown blocks
            const cleanJson = text.replace(/```json/g, '').replace(/```/g, '').trim();
            return JSON.parse(cleanJson);
        } catch (e: any) {
            console.error("[KYC Scan] AI Engine Error:", e);
            throw new Error(`AI_SCAN_FAULT: ${e.message || 'The AI engine could not process the document image. Please ensure the image is clear and well-lit.'}`);
        }
    }
    
    /**
     * Submit a new KYC request.
     * Updates user status to 'pending_review'.
     */
    static async submitKYC(userId: string, data: {
        full_name: string;
        id_type: 'NATIONAL_ID' | 'DRIVER_LICENSE' | 'VOTER_ID' | 'PASSPORT';
        id_number: string;
        document_url: string;
        selfie_url: string;
        metadata?: any;
    }) {
        const sb = getAdminSupabase();
        
        // 1. Supabase Implementation
        if (sb) {
            // Insert request
            const { data: request, error } = await sb.from('kyc_requests').insert({
                user_id: userId,
                ...data,
                status: 'PENDING'
            }).select().single();

            if (error) throw new Error(error.message);

            // Update user status
            await sb.from('users').update({
                kyc_status: 'pending_review'
            }).eq('id', userId);

            return request;
        }

        // 2. Local Fallback
        const requests = Storage.getFromDB<KYCRequest>(STORAGE_KEYS.KYC_REQUESTS || 'kyc_requests') || [];
        const newRequest: KYCRequest = {
            id: UUID.generate(),
            user_id: userId,
            ...data,
            status: 'PENDING',
            submitted_at: new Date().toISOString(),
            metadata: data.metadata || {}
        };
        requests.push(newRequest);
        Storage.saveToDB(STORAGE_KEYS.KYC_REQUESTS || 'kyc_requests', requests);

        // Update local user
        const users = Storage.getFromDB<any>(STORAGE_KEYS.CUSTOM_USERS);
        const idx = users.findIndex(u => u.id === userId);
        if (idx >= 0) {
            users[idx].kyc_status = 'pending_review';
            Storage.saveToDB(STORAGE_KEYS.CUSTOM_USERS, users);
        }

        return newRequest;
    }

    /**
     * Get KYC status for a user.
     */
    static async getKYCStatus(userId: string) {
        const sb = getAdminSupabase();
        if (sb) {
            const { data } = await sb.from('users').select('kyc_status, kyc_level, id_type, id_number').eq('id', userId).single();
            return data || { kyc_status: 'unverified', kyc_level: 0 };
        }
        
        const users = Storage.getFromDB<any>(STORAGE_KEYS.CUSTOM_USERS);
        const user = users.find(u => u.id === userId);
        return user ? { 
            kyc_status: user.kyc_status, 
            kyc_level: user.kyc_level,
            id_type: user.id_type,
            id_number: user.id_number
        } : { kyc_status: 'unverified', kyc_level: 0 };
    }

    /**
     * Admin: Get All KYC Requests (Paginated & Filtered)
     */
    static async getKYCRequests(status?: string, limit: number = 50, offset: number = 0) {
        const sb = getAdminSupabase();
        if (sb) {
            let query = sb.from('kyc_requests').select('*', { count: 'exact' });
            
            if (status) {
                query = query.eq('status', status);
            }
            
            const { data, count, error } = await query
                .range(offset, offset + limit - 1)
                .order('submitted_at', { ascending: false });
                
            if (error) throw new Error(error.message);
            
            return { requests: data, total: count };
        }

        // Local Fallback
        let requests = Storage.getFromDB<KYCRequest>('kyc_requests') || [];
        if (status) {
            requests = requests.filter(r => r.status === status);
        }
        // Sort desc
        requests.sort((a, b) => new Date(b.submitted_at || 0).getTime() - new Date(a.submitted_at || 0).getTime());
        
        const paginated = requests.slice(offset, offset + limit);
        return { requests: paginated, total: requests.length };
    }

    /**
     * Admin: Review KYC Request
     */
    static async reviewKYC(requestId: string, adminId: string, decision: 'APPROVED' | 'REJECTED', reason?: string) {
        const sb = getAdminSupabase();
        let userId = '';

        if (sb) {
            // Update Request
            const { data: request, error } = await sb.from('kyc_requests').update({
                status: decision,
                reviewer_id: adminId,
                reviewed_at: new Date().toISOString(),
                rejection_reason: reason
            }).eq('id', requestId).select().single();

            if (error || !request) throw new Error("Request not found or update failed");
            userId = request.user_id;

            // Update User Profile if Approved
            if (decision === 'APPROVED') {
                await sb.from('users').update({
                    kyc_status: 'verified',
                    kyc_level: 2, // Level 2 unlocks full features
                    account_status: 'active', // Ensure account is active
                    id_type: request.id_type,
                    id_number: request.id_number
                }).eq('id', userId);
            } else {
                await sb.from('users').update({
                    kyc_status: 'rejected'
                }).eq('id', userId);
            }
        } else {
            // Local Fallback
            const requests = Storage.getFromDB<KYCRequest>('kyc_requests');
            const idx = requests.findIndex(r => r.id === requestId);
            if (idx === -1) throw new Error("Request not found");

            requests[idx].status = decision;
            requests[idx].reviewed_at = new Date().toISOString();
            requests[idx].reviewer_id = adminId;
            requests[idx].rejection_reason = reason;
            Storage.saveToDB('kyc_requests', requests);
            userId = requests[idx].user_id;

            // Update User
            const users = Storage.getFromDB<any>(STORAGE_KEYS.CUSTOM_USERS);
            const uIdx = users.findIndex(u => u.id === userId);
            if (uIdx >= 0) {
                if (decision === 'APPROVED') {
                    users[uIdx].kyc_status = 'verified';
                    users[uIdx].kyc_level = 2;
                    users[uIdx].id_type = requests[idx].id_type;
                    users[uIdx].id_number = requests[idx].id_number;
                } else {
                    users[uIdx].kyc_status = 'rejected';
                }
                Storage.saveToDB(STORAGE_KEYS.CUSTOM_USERS, users);
            }
        }

        // Send Notification
        if (userId) {
            const sb = getAdminSupabase();
            let language = 'en';
            if (sb) {
                const { data: user } = await sb.from('users').select('language').eq('id', userId).maybeSingle();
                language = user?.language || 'en';
            }

            const subject = decision === 'APPROVED' 
                ? (language === 'sw' ? 'Utambulisho Umethibitishwa' : 'Identity Verified') 
                : (language === 'sw' ? 'Taarifa ya Uthibitishaji' : 'Verification Update');
            
            const body = decision === 'APPROVED' 
                ? (language === 'sw' ? 'Uthibitishaji wako wa KYC umekamilika. Sasa una ufikiaji kamili wa vipengele vyote.' : 'Your KYC verification is complete. You now have full access to all sovereign features.') 
                : (language === 'sw' ? `Uthibitishaji wako wa KYC umekataliwa. Sababu: ${reason || 'Uthibitishaji wa hati umeshindwa.'}` : `Your KYC verification was rejected. Reason: ${reason || 'Document verification failed.'}`);
            
            await Messaging.dispatch(userId, 'security', subject, body, { sms: true });
        }

        return { success: true };
    }
}
