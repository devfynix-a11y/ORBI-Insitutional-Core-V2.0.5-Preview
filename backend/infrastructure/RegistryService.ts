
import { UUID } from '../../services/utils.js';
import { Storage } from '../storage.js';
import { getSupabase } from '../../services/supabaseClient.js';

/**
 * PLATFORM FRAMEWORK REGISTRY (V12.0)
 * -----------------------------------
 * The 'Brain' of the Sovereign Node. Controls service lifecycle,
 * routing weights, and feature flagging via UI-driven persistence.
 */

export interface ServiceDefinition {
    id: string;
    name: string;
    version: string;
    domain: 'TRANSACTION' | 'IDENTITY' | 'COGNITIVE' | 'CORE';
    status: 'PRODUCTION' | 'MAINTENANCE' | 'DEPRECATED' | 'OFFLINE';
    scaling_tier: 'AUTO' | 'FIXED' | 'BURST';
    self_healing_enabled: boolean;
    lastDeploy: string;
    config_schema?: any;
}

class RegistryNode {
    private readonly STORAGE_KEY = 'dps_service_registry_v12';
    private readonly FLAGS_KEY = 'dps_system_flags';

    constructor() {
        this.init();
    }

    private init() {
        const existing = Storage.getItem(this.STORAGE_KEY);
        if (!existing) {
            const initialCatalog: ServiceDefinition[] = [
                {
                    id: 'svc-ledger',
                    name: 'Titanium Ledger Core',
                    version: '21.5.0',
                    domain: 'TRANSACTION',
                    status: 'PRODUCTION',
                    scaling_tier: 'AUTO',
                    self_healing_enabled: true,
                    lastDeploy: new Date().toISOString()
                },
                {
                    id: 'svc-sentinel',
                    name: 'Cyber Sentinel AI',
                    version: '6.2.0',
                    domain: 'COGNITIVE',
                    status: 'PRODUCTION',
                    scaling_tier: 'BURST',
                    self_healing_enabled: true,
                    lastDeploy: new Date().toISOString()
                },
                {
                    id: 'svc-iam',
                    name: 'Identity Gateway',
                    version: '10.4.1',
                    domain: 'IDENTITY',
                    status: 'PRODUCTION',
                    scaling_tier: 'AUTO',
                    self_healing_enabled: true,
                    lastDeploy: new Date().toISOString()
                }
            ];
            Storage.setItem(this.STORAGE_KEY, JSON.stringify(initialCatalog));
        }

        const flags = Storage.getItem(this.FLAGS_KEY);
        if (!flags) {
            Storage.setItem(this.FLAGS_KEY, JSON.stringify({
                autonomous_healing: true,
                auto_reconcile: true,
                neural_risk_checks: true,
                maintenance_mode: false
            }));
        }
    }

    public getCatalog(): ServiceDefinition[] {
        return JSON.parse(Storage.getItem(this.STORAGE_KEY) || '[]');
    }

    public async updateService(id: string, updates: Partial<ServiceDefinition>) {
        const catalog = this.getCatalog();
        const idx = catalog.findIndex(s => s.id === id);
        if (idx !== -1) {
            catalog[idx] = { ...catalog[idx], ...updates, lastDeploy: new Date().toISOString() };
            Storage.setItem(this.STORAGE_KEY, JSON.stringify(catalog));
            
            // Sync to cloud if available
            const sb = getSupabase();
            if (sb) {
                await sb.from('platform_configs').upsert({
                    config_key: 'SERVICE_CATALOG_STATE',
                    config_data: catalog,
                    updated_at: new Date().toISOString()
                });
            }
        }
    }

    public getSystemFlags() {
        return JSON.parse(Storage.getItem(this.FLAGS_KEY) || '{}');
    }

    public setSystemFlag(key: string, value: boolean) {
        const flags = this.getSystemFlags();
        flags[key] = value;
        Storage.setItem(this.FLAGS_KEY, JSON.stringify(flags));
    }
}

export const RegistryService = new RegistryNode();
