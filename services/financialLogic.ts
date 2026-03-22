import { Transaction, Wallet, Goal, FinancialOverview } from '../types.js';

/**
 * SHARED FINANCIAL COMPUTATION ENGINE
 * Decoupled from server/client state for cross-node portability.
 */
export const FinancialLogic = {
    calculateOverview(transactions: Transaction[], wallets: Wallet[], goals: Goal[]): FinancialOverview {
        const netWorth = wallets.reduce((sum, w) => sum + (w.actualBalance || w.balance || 0), 0);
        let totalIncome = 0;
        let totalExpenses = 0;
        
        transactions.forEach(t => {
            if (t.type === 'deposit') {
                totalIncome += t.amount;
            } else if (['expense', 'bill_payment', 'withdrawal', 'transfer'].includes(t.type)) {
                // Internal transfers shouldn't count as expenses for the net flow
                if (t.type === 'transfer' && t.toWalletId) return;
                totalExpenses += t.amount;
            }
        });

        const allocatedToGoals = goals.reduce((sum, g) => sum + (g.current || 0), 0);
        const savingsRate = totalIncome > 0 ? ((totalIncome - totalExpenses) / totalIncome) * 100 : 0;
        
        const goalProgressRate = goals.length > 0 
            ? goals.reduce((sum, g) => sum + (g.target > 0 ? (g.current / g.target) * 100 : 0), 0) / goals.length 
            : 0;

        return {
            totalIncome,
            totalExpenses,
            allocatedToGoals,
            availableBalance: netWorth,
            netWorth,
            orbiBalance: netWorth,
            savingsRate,
            goalProgressRate
        };
    }
};