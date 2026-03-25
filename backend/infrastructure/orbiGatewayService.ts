import parsePhoneNumber from 'libphonenumber-js';
import { TemplateName, TemplatePayloads } from '../templates/template_types.js';

export class OrbiGatewayService {
    private apiKey: string | undefined;
    private baseUrl: string | undefined;

    constructor() {
        this.apiKey = process.env.ORBI_GATEWAY_API_KEY;
        this.baseUrl = this.normalizeBaseUrl(
            process.env.ORBI_GATEWAY_URL || process.env.ORBI_GATEWAY_BASE_URL
        );
        
        if (!this.apiKey) {
            console.warn('OrbiGatewayService: ORBI_GATEWAY_API_KEY is missing.');
        }
        if (!this.baseUrl) {
            console.warn('OrbiGatewayService: ORBI_GATEWAY_URL is missing.');
        }
    }

    private normalizeBaseUrl(url?: string): string | undefined {
        const raw = url?.trim();
        if (!raw) return undefined;
        return raw.replace(/\/+$/, '').replace(/\/api$/, '');
    }

    private normalizePhone(phone: string): string {
        try {
            const parsed = parsePhoneNumber(phone, 'TZ');
            if (parsed && parsed.isValid()) {
                return parsed.format('E.164');
            }
            return phone.startsWith('+') ? phone : '+' + phone.replace(/\s/g, '');
        } catch (e) {
            return phone.startsWith('+') ? phone : '+' + phone.replace(/\s/g, '');
        }
    }

    async sendSms(recipient: string, body: string, language: string = 'en', ownerUid?: string, ownerEmail?: string, requestId?: string): Promise<boolean> {
        if (!this.apiKey || !this.baseUrl) {
            console.error('OrbiGatewayService: Missing configuration. SMS not sent.');
            return false;
        }

        const normalizedRecipient = this.normalizePhone(recipient);

        try {
            const endpoint = `${this.baseUrl}/api/send-sms`;
            const response = await fetch(endpoint, {
                method: 'POST',
                headers: {
                    'Content-Type': 'application/json',
                    'x-api-key': this.apiKey
                },
                body: JSON.stringify({
                    phone: normalizedRecipient,
                    message: body,
                    messageType: 'transactional',
                    language,
                    ownerUid: process.env.OBI_GATEWAY_USER_ID,
                    ownerEmail: process.env.OBI_GATEWAY_USER_EMAIL,
                    requestId
                })
            });

            if (!response.ok) {
                const errorText = await response.text();
                console.error(`OrbiGatewayService: Failed to send SMS. Endpoint: ${endpoint}, Status: ${response.status}, Error: ${errorText}`);
                return false;
            }

            console.log(`OrbiGatewayService: SMS sent successfully to ${normalizedRecipient}`);
            return true;
        } catch (error) {
            console.error('OrbiGatewayService: Error sending SMS:', error);
            return false;
        }
    }

    async sendEmail(recipient: string, subject: string, body: string, html?: string, language: string = 'en', ownerUid?: string, ownerEmail?: string, requestId?: string): Promise<boolean> {
        if (!this.apiKey || !this.baseUrl) {
            console.error('OrbiGatewayService: Missing configuration. Email not sent.');
            return false;
        }

        try {
            const endpoint = `${this.baseUrl}/api/send-email`;
            const response = await fetch(endpoint, {
                method: 'POST',
                headers: {
                    'Content-Type': 'application/json',
                    'x-api-key': this.apiKey
                },
                body: JSON.stringify({
                    recipient,
                    subject,
                    message: body,
                    html,
                    messageType: 'transactional',
                    language,
                    ownerUid: process.env.OBI_GATEWAY_USER_ID,
                    ownerEmail: process.env.OBI_GATEWAY_USER_EMAIL,
                    requestId
                })
            });

            if (!response.ok) {
                const errorText = await response.text();
                console.error(`OrbiGatewayService: Failed to send Email. Endpoint: ${endpoint}, Status: ${response.status}, Error: ${errorText}`);
                return false;
            }

            console.log(`OrbiGatewayService: Email sent successfully to ${recipient}`);
            return true;
        } catch (error) {
            console.error('OrbiGatewayService: Error sending Email:', error);
            return false;
        }
    }

    async sendPush(fcmToken: string, title: string, body: string, data: Record<string, any> = {}, language: string = 'en', ownerUid?: string, ownerEmail?: string, requestId?: string): Promise<boolean> {
        if (!this.apiKey || !this.baseUrl) {
            console.error('OrbiGatewayService: Missing configuration. Push notification not sent.');
            return false;
        }

        try {
            const payload = {
                token: fcmToken,
                title,
                body,
                data,
                language,
                ownerUid: process.env.OBI_GATEWAY_USER_ID,
                ownerEmail: process.env.OBI_GATEWAY_USER_EMAIL,
                requestId
            };

            console.log(`[OrbiGatewayService] Full Push Payload for POST request: ${JSON.stringify(payload, null, 2)}`);

            const endpoint = `${this.baseUrl}/api/send-push`;
            const response = await fetch(endpoint, {
                method: 'POST',
                headers: {
                    'Content-Type': 'application/json',
                    'x-api-key': this.apiKey
                },
                body: JSON.stringify(payload)
            });

            if (!response.ok) {
                const errorText = await response.text();
                console.error(`OrbiGatewayService: Failed to send Push. Endpoint: ${endpoint}, Status: ${response.status}, Error: ${errorText}`);
                return false;
            }

            console.log(`OrbiGatewayService: Push notification sent successfully.`);
            return true;
        } catch (error) {
            console.error('OrbiGatewayService: Error sending Push:', error);
            return false;
        }
    }

    async sendTemplate<T extends TemplateName>(
        templateName: T, 
        recipient: string, 
        data: TemplatePayloads[T], 
        options: { channel?: string; language?: string; messageType?: 'transactional' | 'promotional'; fcmToken?: string; ownerUid?: string; ownerEmail?: string; requestId?: string } = {}
    ): Promise<boolean> {
        if (!this.apiKey || !this.baseUrl) {
            console.error('OrbiGatewayService: Missing configuration. Template message not sent.');
            return false;
        }

        const { channel = 'sms', language = 'en', messageType = 'transactional', fcmToken, ownerUid, ownerEmail, requestId } = options;

        const normalizedRecipient = (channel === 'sms' || channel === 'whatsapp') ? this.normalizePhone(recipient) : recipient;

        try {
            const payload = {
                templateName,
                recipient: normalizedRecipient,
                data,
                channel,
                language,
                messageType,
                ownerUid: ownerUid || process.env.OBI_GATEWAY_USER_ID,
                ownerEmail: ownerEmail || process.env.OBI_GATEWAY_USER_EMAIL,
                requestId,
                ...(fcmToken && channel !== 'push' ? { fcmToken } : {})
            };

            console.log(`[OrbiGatewayService] Full Template Payload for POST request: ${JSON.stringify(payload, null, 2)}`);

            const endpoint = `${this.baseUrl}/api/send-template`;
            const response = await fetch(endpoint, {
                method: 'POST',
                headers: {
                    'Content-Type': 'application/json',
                    'x-api-key': this.apiKey
                },
                body: JSON.stringify(payload)
            });

            if (!response.ok) {
                const errorText = await response.text();
                console.error(`OrbiGatewayService: Failed to send template message. Endpoint: ${endpoint}, Status: ${response.status}, Error: ${errorText}`);
                return false;
            }

            console.log(`OrbiGatewayService: Template message (${templateName}) sent successfully to ${recipient} via ${channel}`);
            return true;
        } catch (error) {
            console.error('OrbiGatewayService: Error sending template message:', error);
            return false;
        }
    }
}

export const orbiGatewayService = new OrbiGatewayService();
