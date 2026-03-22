
import { FinancialPartner, RestEndpointConfig } from '../../../types.js';
import { IPaymentProvider, ProviderResponse } from './types.js';

/**
 * UNIVERSAL REST ADAPTER (V2.0)
 * ----------------------------
 * Handles standard providers via DB-defined JSON mappings.
 * Supports dynamic payload templating and endpoint configuration.
 */
export class GenericRestProvider implements IPaymentProvider {
    
    public async authenticate(partner: FinancialPartner): Promise<string> {
        // Generic OAuth flow or API Key usage
        return partner.token_cache || 'api_key_auth';
    }

    public async stkPush(partner: FinancialPartner, phone: string, amount: number, reference: string): Promise<ProviderResponse> {
        const config = partner.mapping_config?.stk_push;
        if (!config) throw new Error("STK_PUSH_CONFIG_MISSING");

        const context = { phone, amount, reference, partner };
        const response = await this.executeRequest(config, context);

        return {
            success: true,
            providerRef: response.external_id || `GEN-${Math.random().toString(36).substring(7).toUpperCase()}`,
            message: response.status || `Generic request sent to ${partner.name}.`,
            rawPayload: response.raw
        };
    }

    public async disburse(partner: FinancialPartner, phone: string, amount: number, reference: string): Promise<ProviderResponse> {
        const config = partner.mapping_config?.disbursement;
        if (!config) throw new Error("DISBURSEMENT_CONFIG_MISSING");

        const context = { phone, amount, reference, partner };
        const response = await this.executeRequest(config, context);

        return {
            success: true,
            providerRef: response.external_id || `GEN-PAY-${Math.random().toString(36).substring(7).toUpperCase()}`,
            message: response.status || "Disbursement processed via Generic REST node.",
            rawPayload: response.raw
        };
    }

    public parseCallback(payload: any) {
        // In a real generic implementation, we would use JSONPath or a simple key map
        // For this node, we assume a standard status check
        const isSuccess = payload.status === 'SUCCESS' || payload.code === 200;
        return {
            reference: payload.reference || payload.id || '',
            status: (isSuccess ? 'completed' : 'failed') as any,
            message: payload.message || 'Generic Callback Received'
        };
    }

    public async getBalance(partner: FinancialPartner): Promise<number> {
        const config = partner.mapping_config?.balance;
        if (!config) {
            console.warn(`[GenericRestProvider] Balance config missing for ${partner.name}`);
            return 0;
        }

        const context = { partner };
        const response = await this.executeRequest(config, context);
        
        if (config.response_mapping?.balance_field) {
            const balance = this.getValueByPath(response.raw, config.response_mapping.balance_field);
            return Number(balance) || 0;
        }
        
        return 0;
    }

    private async executeRequest(config: RestEndpointConfig, context: any): Promise<any> {
        // 1. Resolve Endpoint
        const url = this.resolveTemplate(config.url, context);

        // 2. Resolve Headers
        const headers = this.resolveHeaders(config.headers || {}, context);

        // 3. Resolve Payload
        const body = config.payload_template 
            ? JSON.stringify(this.resolveObject(config.payload_template, context))
            : undefined;

        console.log(`[GenericRestProvider] Executing ${config.method} ${url}`);
        
        try {
            const response = await fetch(url, {
                method: config.method,
                headers,
                body
            });

            const responseData = await response.json();

            if (!response.ok) {
                throw new Error(responseData.message || `HTTP Error ${response.status}: ${response.statusText}`);
            }

            if (config.response_mapping) {
                return {
                    external_id: config.response_mapping.id_field ? this.getValueByPath(responseData, config.response_mapping.id_field) : undefined,
                    status: config.response_mapping.status_field ? this.getValueByPath(responseData, config.response_mapping.status_field) : undefined,
                    raw: responseData
                };
            }

            return { raw: responseData };
        } catch (error) {
            console.error(`[GenericRestProvider] Error:`, error);
            throw error;
        }
    }

    private resolveTemplate(template: string, context: any): string {
        return template.replace(/\{\{(.*?)\}\}/g, (_, key) => {
            const value = this.getValueByPath(context, key.trim());
            return value !== undefined && value !== null ? String(value) : '';
        });
    }

    private resolveHeaders(headers: Record<string, string>, context: any): Record<string, string> {
        const resolved: Record<string, string> = {};
        for (const [key, value] of Object.entries(headers)) {
            resolved[key] = this.resolveTemplate(value, context);
        }
        return resolved;
    }

    private resolveObject(template: any, context: any): any {
        if (typeof template === 'string') {
            const match = template.match(/^\{\{(.*?)\}\}$/);
            if (match) {
                const value = this.getValueByPath(context, match[1].trim());
                return value !== undefined ? value : template; 
            }
            return this.resolveTemplate(template, context);
        } else if (Array.isArray(template)) {
            return template.map(item => this.resolveObject(item, context));
        } else if (typeof template === 'object' && template !== null) {
            const resolved: any = {};
            for (const [key, value] of Object.entries(template)) {
                resolved[key] = this.resolveObject(value, context);
            }
            return resolved;
        }
        return template;
    }

    private getValueByPath(obj: any, path: string): any {
        return path.split('.').reduce((acc: any, part: string) => {
            if (acc === null || acc === undefined) return undefined;
            return acc[part];
        }, obj);
    }
}
