import { orbiGatewayService } from '../backend/infrastructure/orbiGatewayService.js';

/**
 * EXTERNAL MESSAGE PROVIDER SERVICE
 */
export const SMSProvider = {
    sendOTP: async (phone: string, otp: string, language: string = 'en'): Promise<boolean> => {
        console.log(`[Identity Gateway] Verification node pulse sent to ${phone}`);
        
        // Android SMS Retriever Hash
        const ANDROID_HASH = process.env.ORBI_ANDROID_SMS_HASH;
        
        return orbiGatewayService.sendTemplate('OTP_Message', phone, { 
            otp, 
            androidHash: ANDROID_HASH 
        }, { messageType: 'transactional', language, channel: 'sms' });
    },

    sendMessage: async (phone: string, message: string, language: string = 'en'): Promise<boolean> => {
        return orbiGatewayService.sendTemplate('Transactional_Message', phone, { 
            body: message 
        }, { messageType: 'transactional', language, channel: 'sms' });
    },

    sendWelcome: async (phone: string, name: string, language: string = 'en'): Promise<boolean> => {
        return orbiGatewayService.sendTemplate('Welcome_Message', phone, { 
            name 
        }, { messageType: 'promotional', language, channel: 'sms' });
    },

    sendSecurityAlert: async (phone: string, subject: string, body: string, language: string = 'en'): Promise<boolean> => {
        return orbiGatewayService.sendTemplate('Security_Alert_Message', phone, { 
            subject,
            body
        }, { messageType: 'transactional', language, channel: 'sms' });
    },

    sendPromo: async (phone: string, offer: string, language: string = 'en'): Promise<boolean> => {
        return orbiGatewayService.sendTemplate('Promo_Message', phone, { 
            body: offer 
        }, { messageType: 'promotional', language, channel: 'sms' });
    },

    sendEscrowCreated: async (phone: string, amount: string, currency: string, language: string = 'en'): Promise<boolean> => {
        return orbiGatewayService.sendTemplate('Escrow_Created', phone, { 
            amount,
            currency
        }, { messageType: 'transactional', language, channel: 'sms' });
    },

    sendSalaryReceived: async (phone: string, amount: string, currency: string, employeeName: string, month: string, timestamp: string, refId: string, language: string = 'en'): Promise<boolean> => {
        return orbiGatewayService.sendTemplate('Salary_Received', phone, { 
            amount,
            currency,
            employeeName,
            month,
            timestamp,
            refId
        }, { messageType: 'transactional', language, channel: 'sms' });
    },

    sendTransferReceived: async (phone: string, amount: string, currency: string, senderName: string, recipientName: string, timestamp: string, refId: string, language: string = 'en'): Promise<boolean> => {
        return orbiGatewayService.sendTemplate('Transfer_Received', phone, { 
            amount,
            currency,
            senderName,
            recipientName,
            timestamp,
            refId
        }, { messageType: 'transactional', language, channel: 'sms' });
    },

    sendTransferSent: async (phone: string, amount: string, currency: string, senderName: string, recipientName: string, timestamp: string, refId: string, language: string = 'en'): Promise<boolean> => {
        return orbiGatewayService.sendTemplate('Transfer_Sent', phone, { 
            amount,
            currency,
            senderName,
            recipientName,
            timestamp,
            refId
        }, { messageType: 'transactional', language, channel: 'sms' });
    },

    sendTemplate: async (templateName: string, phone: string, variables: Record<string, any>, options?: any): Promise<boolean> => {
        return await orbiGatewayService.sendTemplate(templateName as any, phone, variables, options);
    },

    validatePhone: (phone: string): boolean => {
        const phoneRegex = /^(\+?\d{9,15})$/;
        return phoneRegex.test(phone.replace(/[\s-]/g, ''));
    }
};
