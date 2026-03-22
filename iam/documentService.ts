import { getAdminSupabase } from '../services/supabaseClient.js';
import { UUID } from '../services/utils.js';

export class DocumentService {
    /**
     * Upload a new document metadata.
     */
    static async uploadDocument(userId: string, data: {
        document_type: string;
        file_url: string;
        file_name?: string;
        mime_type?: string;
        size_bytes?: number;
        metadata?: any;
    }) {
        const sb = getAdminSupabase();
        if (!sb) throw new Error("Database connection unavailable");

        const { data: newDoc, error } = await sb.from('user_documents').insert({
            user_id: userId,
            ...data,
            status: 'pending',
            uploaded_at: new Date().toISOString()
        }).select().single();

        if (error) throw new Error(error.message);
        return newDoc;
    }

    /**
     * Get all documents for a user.
     */
    static async getUserDocuments(userId: string) {
        const sb = getAdminSupabase();
        if (!sb) throw new Error("Database connection unavailable");

        const { data, error } = await sb.from('user_documents')
            .select('*')
            .eq('user_id', userId)
            .order('uploaded_at', { ascending: false });

        if (error) throw new Error(error.message);
        return data;
    }

    /**
     * Remove a document.
     */
    static async removeDocument(userId: string, documentId: string) {
        const sb = getAdminSupabase();
        if (!sb) throw new Error("Database connection unavailable");

        const { error } = await sb.from('user_documents')
            .delete()
            .eq('id', documentId)
            .eq('user_id', userId);

        if (error) throw new Error(error.message);
        return { success: true };
    }

    /**
     * Admin: Get all documents (paginated)
     */
    static async getAllDocuments(limit: number = 50, offset: number = 0) {
        const sb = getAdminSupabase();
        if (!sb) throw new Error("Database connection unavailable");

        const { data, count, error } = await sb.from('user_documents')
            .select('*', { count: 'exact' })
            .range(offset, offset + limit - 1)
            .order('uploaded_at', { ascending: false });

        if (error) throw new Error(error.message);
        return { documents: data, total: count };
    }

    /**
     * Admin: Verify or reject document
     */
    static async verifyDocument(documentId: string, adminId: string, data: { status: string; rejection_reason?: string }) {
        const sb = getAdminSupabase();
        if (!sb) throw new Error("Database connection unavailable");

        const { data: updated, error } = await sb.from('user_documents')
            .update({
                status: data.status,
                rejection_reason: data.rejection_reason || null,
                verified_at: new Date().toISOString(),
                verified_by: adminId
            })
            .eq('id', documentId)
            .select()
            .single();

        if (error) throw new Error(error.message);
        return updated;
    }
}
