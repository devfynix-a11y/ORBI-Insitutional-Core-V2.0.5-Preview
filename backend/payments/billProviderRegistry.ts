import {
    normalizeFinancialPartnerMetadata,
    resolveProviderCode,
} from './financialPartnerMetadata.js';

export type BillProviderRecord = {
    label: string;
    provider_code?: string;
    display_icon?: string;
    color?: string;
    logo_url?: string;
    metadata: Record<string, unknown>;
};

export type BillProviderCategoryRecord = {
    key: string;
    label: string;
    providers: BillProviderRecord[];
};

const billCategoryLabels: Record<string, string> = {
    electricity: 'Electricity',
    'school-fees': 'School fees',
    'water-bills': 'Water bills',
    gas: 'Gas',
    bundles: 'Bundles',
    internet: 'Internet',
    'government-bills': 'Government bills',
    insurance: 'Insurance',
    telephone: 'Telephone',
    entertainment: 'Entertainment',
    'other-bills': 'Other bills',
};

function normalizeBillCategoryKey(raw: unknown): string {
    const value = String(raw || '')
        .trim()
        .toLowerCase()
        .replace(/[_\s]+/g, '-');
    if (!value) return '';
    if (value === 'school_fees') return 'school-fees';
    if (value === 'water' || value === 'water-bill' || value === 'water-bills') return 'water-bills';
    if (value === 'government' || value === 'government-bill' || value === 'government-bills') return 'government-bills';
    if (value === 'other' || value === 'other-bill' || value === 'other-bills') return 'other-bills';
    return value;
}

function normalizeBillProviderName(raw: unknown): string {
    return String(raw || '').trim();
}

function readStringArray(value: unknown): string[] {
    if (Array.isArray(value)) {
        return value.map((item) => String(item || '').trim()).filter(Boolean);
    }
    if (typeof value === 'string') {
        return value
            .split(',')
            .map((item) => item.trim())
            .filter(Boolean);
    }
    return [];
}

export function resolveBillCategoryKeys(partner: any): string[] {
    const metadata = partner?.provider_metadata && typeof partner.provider_metadata === 'object'
        ? partner.provider_metadata
        : {};
    const explicit = [
        ...readStringArray(metadata.bill_categories),
        ...readStringArray(metadata.billCategories),
        ...readStringArray(metadata.service_categories),
        ...readStringArray(metadata.serviceCategories),
        ...readStringArray(metadata.category),
        ...readStringArray(metadata.service_category),
        ...readStringArray(metadata.serviceCategory),
    ]
        .map(normalizeBillCategoryKey)
        .filter(Boolean);

    return Array.from(new Set(explicit));
}

export function supportsBillPayments(partner: any): boolean {
    const metadata = partner?.provider_metadata && typeof partner.provider_metadata === 'object'
        ? partner.provider_metadata
        : {};
    const operations = readStringArray(metadata.operations).map((item) => item.toUpperCase());
    const capabilities = readStringArray(metadata.capabilities).map((item) => item.toUpperCase());
    const channels = readStringArray(metadata.channels).map((item) => item.toLowerCase());
    return (
        operations.includes('COLLECTION_REQUEST') ||
        operations.includes('BILL_PAYMENT') ||
        capabilities.includes('BILL_PAYMENT') ||
        channels.includes('bill_pay') ||
        channels.includes('bill_payment') ||
        resolveBillCategoryKeys(partner).length > 0
    );
}

export async function listRegistryBackedBillProviders(
    sb: any,
): Promise<BillProviderCategoryRecord[]> {
    const { data: partners, error } = await sb
        .from('financial_partners')
        .select('id, name, type, icon, color, status, provider_metadata')
        .eq('status', 'ACTIVE');
    if (error) throw error;

    const bucket = new Map<string, Map<string, BillProviderRecord>>();
    for (const partner of partners || []) {
        if (!supportsBillPayments(partner)) continue;
        const metadata = normalizeFinancialPartnerMetadata(partner);
        const providerName = normalizeBillProviderName(
            metadata.brand_name || metadata.display_name || partner?.name,
        );
        if (!providerName) continue;
        const providerCode = resolveProviderCode(partner) || undefined;
        const providerRecord: BillProviderRecord = {
            label: providerName,
            ...(providerCode ? { provider_code: providerCode } : {}),
            ...(metadata.display_icon ? { display_icon: String(metadata.display_icon) } : {}),
            ...(metadata.color ? { color: String(metadata.color) } : {}),
            ...((metadata as any).logo_url || (metadata as any).logoUrl
                ? { logo_url: String((metadata as any).logo_url || (metadata as any).logoUrl) }
                : {}),
            metadata: {
                group: metadata.group,
                rail: metadata.rail,
                brand_name: metadata.brand_name,
                display_name: metadata.display_name,
                display_icon: metadata.display_icon,
                provider_code: metadata.provider_code,
                color: metadata.color,
                logo_url: (metadata as any).logo_url || (metadata as any).logoUrl || '',
                channels: metadata.channels,
                bill_categories: metadata.bill_categories || metadata.billCategories || [],
                operations: metadata.operations,
                checkout_mode: metadata.checkout_mode,
                countries: metadata.countries,
            },
        };
        for (const categoryKey of resolveBillCategoryKeys(partner)) {
            if (!bucket.has(categoryKey)) {
                bucket.set(categoryKey, new Map<string, BillProviderRecord>());
            }
            const categoryProviders = bucket.get(categoryKey)!;
            categoryProviders.set(
                (providerCode || providerName).trim().toUpperCase(),
                providerRecord,
            );
        }
    }

    return Array.from(bucket.entries())
        .map(([key, providers]) => ({
            key,
            label: billCategoryLabels[key] || key,
            providers: Array.from(providers.values()).sort((a, b) =>
                a.label.localeCompare(b.label),
            ),
        }))
        .sort((a, b) => a.label.localeCompare(b.label));
}
