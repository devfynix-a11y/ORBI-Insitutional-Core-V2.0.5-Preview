export type TemplateChannel = 'sms' | 'email' | 'push' | 'whatsapp';
export type TemplateLanguage = 'en' | 'sw';
export type MessageType = 'transactional' | 'promotional';

/**
 * Registry of all supported Orbi Gateway Templates.
 * This ensures type safety across the backend when dispatching notifications.
 */
export interface TemplatePayloads {
    OTP_Message: {
        otp: string;
        name?: string;
        deviceName?: string;
        refId?: string;
        androidHash?: string;
    };
    Welcome_Message: {
        name: string;
    };
    Transfer_Sent: {
        senderName: string;
        recipientName: string;
        currency: string;
        amount: string | number;
        timestamp: string;
        refId: string;
        footer?: string;
    };
    Transfer_Received: {
        senderName: string;
        recipientName: string;
        currency: string;
        amount: string | number;
        timestamp: string;
        refId: string;
        footer?: string;
    };
    Security_Alert_Message: {
        subject: string;
        body: string;
        refId?: string;
    };
    New_Device_Alert: {
        deviceName: string;
        refId?: string;
    };
    Escrow_Created: {
        currency: string;
        amount: string | number;
    };
    Escrow_Released: {
        currency: string;
        amount: string | number;
    };
    Salary_Received: {
        employeeName: string;
        month: string;
        currency: string;
        amount: string | number;
        timestamp: string;
        refId: string;
        footer?: string;
    };
    Treasury_Withdrawal_Request: {
        currency: string;
        amount: string | number;
        reason: string;
    };
    LOW_BALANCE: {
        name: string;
        threshold: string | number;
    };
    Promo_Message: {
        body: string;
    };
    Transactional_Message: {
        body: string;
        refId?: string;
    };
}

export type TemplateName = keyof TemplatePayloads;
