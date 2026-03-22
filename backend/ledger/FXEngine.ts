import axios from 'axios';
import { ConfigClient } from '../infrastructure/RulesConfigClient.js';

export class FXEngine {
    private static ratesCache: Record<string, number> = {};
    private static lastFetch: number = 0;
    private static CACHE_TTL = 3600000; // 1 hour
    private static CONVERSION_FEE_PERCENTAGE = 0.005; // 0.5% fee

    /**
     * Fetch exchange rates.
     * Priority: 1. Admin Overrides (DB) -> 2. Live API -> 3. Fallbacks
     */
    static async fetchRates() {
        if (Date.now() - this.lastFetch < this.CACHE_TTL && Object.keys(this.ratesCache).length > 0) {
            return;
        }

        try {
            // 1. Check Admin Overrides from Database
            const config = await ConfigClient.getRuleConfig();
            if (config.exchange_rates) {
                this.ratesCache = config.exchange_rates;
                this.lastFetch = Date.now();
                console.log("[FXEngine] Using Admin-configured exchange rates.");
                return;
            }

            // 2. Fallback to Live API
            const response = await axios.get('https://open.er-api.com/v6/latest/USD');
            if (response.data && response.data.rates) {
                this.ratesCache = response.data.rates;
                this.lastFetch = Date.now();
                console.log("[FXEngine] Successfully updated live exchange rates from API.");
            }
        } catch (error) {
            console.error("[FXEngine] Failed to fetch rates, using hardcoded fallbacks:", error);
            this.ratesCache = {
                'USD': 1,
                'EUR': 0.92,
                'GBP': 0.78,
                'TZS': 2550,
                'KES': 135,
                'UGX': 3900,
                'RWF': 1280,
                'ZAR': 19,
                'NGN': 1500,
                'GHS': 13.5
            };
        }
    }

    /**
     * Get the exchange rate from one currency to another.
     */
    static async getRate(fromCurrency: string, toCurrency: string): Promise<number> {
        await this.fetchRates();
        const from = fromCurrency.toUpperCase();
        const to = toCurrency.toUpperCase();

        if (from === to) return 1;

        const rateFrom = this.ratesCache[from] || 1; // 1 USD = rateFrom FROM
        const rateTo = this.ratesCache[to] || 1;     // 1 USD = rateTo TO

        // Convert 1 unit of 'from' to 'to'
        // 1 FROM = (1 / rateFrom) USD
        // (1 / rateFrom) USD = (1 / rateFrom) * rateTo TO
        return rateTo / rateFrom;
    }

    /**
     * Convert an amount to USD for standardized AML and Risk checks.
     */
    static async convertToUSD(amount: number, currency: string): Promise<number> {
        const rate = await this.getRate(currency, 'USD');
        return amount * rate;
    }

    /**
     * Process a real currency conversion including a small platform fee.
     * This is used for actual user transactions/pricing.
     */
    static async processConversion(amount: number, fromCurrency: string, toCurrency: string) {
        const rate = await this.getRate(fromCurrency, toCurrency);
        const rawConvertedAmount = amount * rate;
        
        // Add small conversion fee (e.g., 0.5% + fixed cent equivalent)
        const fee = (rawConvertedAmount * this.CONVERSION_FEE_PERCENTAGE);
        const finalAmount = rawConvertedAmount - fee;

        return {
            originalAmount: amount,
            fromCurrency: fromCurrency.toUpperCase(),
            toCurrency: toCurrency.toUpperCase(),
            exchangeRate: rate,
            fee: Number(fee.toFixed(4)),
            finalAmount: Number(finalAmount.toFixed(4))
        };
    }
}
