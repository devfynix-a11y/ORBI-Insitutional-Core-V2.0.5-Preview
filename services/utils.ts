import { createHash } from 'crypto';
import { UserRole, Permission, Transaction, Goal } from '../types.js';
import { PLATFORM_LOGO_LINK } from './platform_Logo.js';

/**
 * PRODUCTION ENVIRONMENT UTILITIES
 */
export const EnvUtils = {
    get: (key: string): string | undefined => {
        if (typeof process !== 'undefined' && process.env && process.env[key]) return process.env[key];
        return undefined;
    },
    getApiKey: (): string | undefined => EnvUtils.get('API_KEY'),
    imageUrlToBase64: async (url: string): Promise<string | null> => {
        // Headless node does not handle local image rasterization
        return null;
    }
};

// FIX: Added APP_LOGO_URL exported constant
export const APP_LOGO_URL = PLATFORM_LOGO_LINK;

export const DateUtils = {
    safeParse: (ds: string) => {
        if (!ds) return new Date();
        return new Date(ds.includes(':') && !ds.includes('Z') && !ds.includes('+') ? ds.replace(' ', 'T') + 'Z' : ds);
    },
    formatDate: (ds: string) => {
        if (!ds) return 'N/A';
        const d = DateUtils.safeParse(ds);
        return d.toLocaleDateString();
    },
    formatTime: (ds: string) => {
        if (!ds) return '--:--';
        return DateUtils.safeParse(ds).toLocaleTimeString();
    },
    formatLocalTimeWithZone: (ds: string) => {
        if (!ds) return 'N/A';
        return DateUtils.safeParse(ds).toLocaleTimeString();
    }
};

export const CurrencyUtils = {
    CURRENCIES: { 
        USD: { symbol: '$', locale: 'en-US' }, 
        TZS: { symbol: 'TSh', locale: 'sw-TZ' },
        KES: { symbol: 'KSh', locale: 'en-KE' }
    } as any,
    formatMoney: (val: number, code = 'USD') => {
        const c = CurrencyUtils.CURRENCIES[code] || CurrencyUtils.CURRENCIES.USD;
        return new Intl.NumberFormat(c.locale, { style: 'currency', currency: code }).format(val || 0);
    },
    getSymbol: (code = 'USD') => (CurrencyUtils.CURRENCIES[code] || CurrencyUtils.CURRENCIES.USD).symbol,
    formatInput: (v: any) => String(v).replace(/[^0-9.]/g, ''),
    parseInput: (v: any) => parseFloat(String(v).replace(/,/g, '')) || 0
};

export const UUID = {
    generate: (): string => {
        return 'xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx'.replace(/[xy]/g, c => {
            const r = Math.random() * 16 | 0;
            return (c == 'x' ? r : (r & 0x3 | 0x8)).toString(16);
        });
    },
    generateShortCode: (length: number = 12): string => {
        const chars = '0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ';
        let result = '';
        for (let i = 0; i < length; i++) {
            result += chars.charAt(Math.floor(Math.random() * chars.length));
        }
        return result;
    }
};

export const RBAC = {
    can: (role: UserRole | string | undefined, permission: Permission): boolean => {
        if (role === 'SUPER_ADMIN') return true;
        return false;
    }
};

// FIX: Added missing IdentityGenerator export
export const IdentityGenerator = {
    generateCustomerID: (prefixOrIdx?: string | number) => {
        const prefix = typeof prefixOrIdx === 'string' ? prefixOrIdx : 'OB';
        const now = new Date();
        const fullYear = now.getFullYear().toString(); // e.g., "2026"
        const year = fullYear.substring(2, 4); // "26"
        
        const rand1 = Math.floor(1000 + Math.random() * 9000).toString(); // 4 random digits
        const rand2 = Math.floor(1000 + Math.random() * 9000).toString(); // 4 random digits
        return `${prefix}${year}-${rand1}-${rand2}`;
    },
    generateDeviceFingerprint: (ua: string): string => {
        return createHash('sha256').update(ua).digest('hex');
    }
};

// FIX: Added missing ValidationUtils export
export const ValidationUtils = {
    isValidIBAN: (v: string) => ({ valid: true, error: '' }),
    formatIBAN: (v: string) => v
};

// FIX: Added missing AllocationUtils export for goal splits
export const AllocationUtils = {
    calculateAllocations: (amount: number, goals: Goal[]) => {
        const autoGoals = goals.filter(g => g.autoAllocationEnabled && g.fundingStrategy !== 'manual');
        return autoGoals.map(g => {
            let share = 0;
            if (g.fundingStrategy === 'percentage' && g.linkedIncomePercentage) {
                share = (amount * g.linkedIncomePercentage) / 100;
            } else if (g.fundingStrategy === 'fixed' && g.monthlyTarget) {
                share = Math.min(amount, g.monthlyTarget);
            }
            return { goalId: g.id, goalName: g.name, amount: share };
        });
    }
};
