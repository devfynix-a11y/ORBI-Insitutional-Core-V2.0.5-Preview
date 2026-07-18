import { type RequestHandler, type Router } from 'express';
import { GoogleGenAI, Type } from '@google/genai';
import { OrbiKnowledge } from '../../constants/orbiKnowledge.js';

type Deps = {
  authenticate: RequestHandler;
  upload: any;
  LogicCore: any;
  getAdminSupabase: () => any;
};

async function callGeminiWithRetry(ai: GoogleGenAI, params: any, retries = 3, delay = 1000): Promise<any> {
  try {
    return await ai.models.generateContent(params);
  } catch (e: any) {
    if (retries > 0 && e.status === 503) {
      console.warn(`[Gemini] 503 error, retrying in ${delay}ms... (${retries} retries left)`);
      await new Promise((resolve) => setTimeout(resolve, delay));
      return callGeminiWithRetry(ai, params, retries - 1, delay * 2);
    }
    throw e;
  }
}

function getFirstUploadedFile(req: any) {
  const files = Array.isArray(req.files) ? req.files : [];
  return req.file || files[0] || null;
}

type InsightPayload = {
  spendingAlerts: string[];
  budgetSuggestions: string[];
  financialAdvice: string[];
};

type StoredInsightRow = {
  insight_type?: string | null;
  title?: string | null;
  message?: string | null;
  severity?: string | null;
  created_at?: string | null;
  metadata?: Record<string, any> | null;
};

function asNumber(value: any): number {
  if (typeof value === 'number') return Number.isFinite(value) ? value : 0;
  if (typeof value === 'string') return Number(value.replace(/,/g, '').trim()) || 0;
  return 0;
}

function firstNonEmpty(...values: Array<any>): string {
  for (const value of values) {
    if (typeof value === 'string' && value.trim()) return value.trim();
  }
  return '';
}

function parseInsightJson(text: string | undefined | null): InsightPayload | null {
  if (!text) return null;
  try {
    const parsed = JSON.parse(text);
    return {
      spendingAlerts: Array.isArray(parsed?.spendingAlerts)
        ? parsed.spendingAlerts.map((item: any) => String(item || '').trim()).filter(Boolean)
        : [],
      budgetSuggestions: Array.isArray(parsed?.budgetSuggestions)
        ? parsed.budgetSuggestions.map((item: any) => String(item || '').trim()).filter(Boolean)
        : [],
      financialAdvice: Array.isArray(parsed?.financialAdvice)
        ? parsed.financialAdvice.map((item: any) => String(item || '').trim()).filter(Boolean)
        : [],
    };
  } catch {
    return null;
  }
}

function pickSeverityLabel(type: string): string {
  const normalized = String(type || '').toUpperCase();
  if (normalized.includes('SPEND')) return 'Spending alert';
  if (normalized.includes('SAVE')) return 'Saving suggestion';
  if (normalized.includes('GOAL')) return 'Goal prediction';
  if (normalized.includes('BUDGET')) return 'Budget warning';
  if (normalized.includes('SECURITY') || normalized.includes('RISK')) return 'Security warning';
  return 'Insight';
}

function buildHeuristicInsights(context: {
  transactions: any[];
  goals: any[];
  categories: any[];
  billReserves: any[];
}): InsightPayload {
  const transactions = context.transactions || [];
  const goals = context.goals || [];
  const categories = context.categories || [];
  const billReserves = context.billReserves || [];

  const spendingAlerts: string[] = [];
  const budgetSuggestions: string[] = [];
  const financialAdvice: string[] = [];

  const categoryPressure = categories
    .map((category: any) => {
      const budget = asNumber(category.budget);
      const spent = asNumber(category.spent_amount ?? category.spent);
      const ratio = budget > 0 ? spent / budget : 0;
      return { category, budget, spent, ratio };
    })
    .sort((a, b) => b.ratio - a.ratio);

  const hottestBudget = categoryPressure.find((entry) => entry.budget > 0);
  if (hottestBudget && hottestBudget.ratio >= 0.85) {
    spendingAlerts.push(
      `${firstNonEmpty(hottestBudget.category.name, 'A budget')} is already at ${(hottestBudget.ratio * 100).toFixed(0)}% of plan.`,
    );
  }

  const recentSpend = transactions.reduce((sum: number, item: any) => {
    const amount = asNumber(item.amount);
    return sum + (amount > 0 ? amount : 0);
  }, 0);
  const totalBudget = categories.reduce((sum: number, item: any) => sum + asNumber(item.budget), 0);
  if (totalBudget > 0 && recentSpend > totalBudget * 0.75) {
    spendingAlerts.push(
      'Recent outflows are consuming most of your active budget envelope. Slow non-essential spending this week.',
    );
  }

  const leadingGoal = goals
    .map((goal: any) => {
      const current = asNumber(goal.current_amount ?? goal.current);
      const target = asNumber(goal.target_amount ?? goal.target);
      const ratio = target > 0 ? current / target : 0;
      return { goal, current, target, ratio };
    })
    .sort((a, b) => b.ratio - a.ratio)[0];
  if (leadingGoal && leadingGoal.target > 0) {
    financialAdvice.push(
      `${firstNonEmpty(leadingGoal.goal.name, 'Your top goal')} is ${(leadingGoal.ratio * 100).toFixed(0)}% funded. Keep the same pace to finish sooner.`,
    );
  } else if (goals.length === 0) {
    financialAdvice.push(
      'Create one active goal so ORBI can separate long-term progress from everyday spending.',
    );
  }

  const underusedBudgets = categoryPressure.filter((entry) => entry.budget > 0 && entry.ratio < 0.35);
  if (underusedBudgets.length > 0) {
    budgetSuggestions.push(
      `You still have room in ${firstNonEmpty(underusedBudgets[0].category.name, 'one budget')}. Redirect a small amount into savings instead of leaving it idle.`,
    );
  }

  if (billReserves.length === 0) {
    financialAdvice.push(
      'Set up a bill reserve so upcoming obligations are protected before daily spending can touch them.',
    );
  }

  if (spendingAlerts.length === 0) {
    spendingAlerts.push('No immediate spending pressure detected from your latest activity.');
  }
  if (budgetSuggestions.length === 0) {
    budgetSuggestions.push('Keep one budget category deliberately underused and route the difference into savings.');
  }
  if (financialAdvice.length === 0) {
    financialAdvice.push('Your money posture looks stable. Maintain consistent savings and review one budget before week end.');
  }

  return {
    spendingAlerts: spendingAlerts.slice(0, 3),
    budgetSuggestions: budgetSuggestions.slice(0, 3),
    financialAdvice: financialAdvice.slice(0, 3),
  };
}

function mapStoredInsightsToPayload(rows: StoredInsightRow[]): InsightPayload {
  const payload: InsightPayload = {
    spendingAlerts: [],
    budgetSuggestions: [],
    financialAdvice: [],
  };
  for (const row of rows) {
    const message = firstNonEmpty(row.message, row.title);
    if (!message) continue;
    const type = String(row.insight_type || '').toUpperCase();
    if (type.includes('SPEND')) {
      payload.spendingAlerts.push(message);
    } else if (type.includes('BUDGET') || type.includes('SAVE')) {
      payload.budgetSuggestions.push(message);
    } else {
      payload.financialAdvice.push(message);
    }
  }
  return payload;
}

function mapPayloadToFeed(payload: InsightPayload) {
  return [
    ...payload.spendingAlerts.map((message) => ({
      type: 'SPENDING_ALERT',
      title: 'Guardian AI',
      message,
      severity: 'WARNING',
      severityLabel: 'Spending alert',
    })),
    ...payload.budgetSuggestions.map((message) => ({
      type: 'SAVING_SUGGESTION',
      title: 'Guardian AI',
      message,
      severity: 'INFO',
      severityLabel: 'Saving suggestion',
    })),
    ...payload.financialAdvice.map((message) => ({
      type: 'GOAL_PREDICTION',
      title: 'Guardian AI',
      message,
      severity: 'INFO',
      severityLabel: 'Goal prediction',
    })),
  ].slice(0, 5);
}

async function fetchStoredWealthInsights(sb: any, userId: string) {
  const { data, error } = await sb
    .from('wealth_insights')
    .select('insight_type,title,message,severity,created_at,metadata')
    .eq('user_id', userId)
    .eq('status', 'ACTIVE')
    .or(`expires_at.is.null,expires_at.gte.${new Date().toISOString()}`)
    .order('created_at', { ascending: false })
    .limit(10);
  if (error) return [];
  return (data || []) as StoredInsightRow[];
}

async function upsertGeneratedInsights(
  sb: any,
  userId: string,
  payload: InsightPayload,
  source: 'AI' | 'HEURISTIC',
) {
  const generated = [
    ...payload.spendingAlerts.map((message) => ({
      user_id: userId,
      insight_type: 'SPENDING_ALERT',
      title: 'Guardian AI',
      message,
      severity: 'WARNING',
      status: 'ACTIVE',
      metadata: { source, audience: 'dashboard_home' },
    })),
    ...payload.budgetSuggestions.map((message) => ({
      user_id: userId,
      insight_type: 'SAVING_SUGGESTION',
      title: 'Guardian AI',
      message,
      severity: 'INFO',
      status: 'ACTIVE',
      metadata: { source, audience: 'dashboard_home' },
    })),
    ...payload.financialAdvice.map((message) => ({
      user_id: userId,
      insight_type: 'GOAL_PREDICTION',
      title: 'Guardian AI',
      message,
      severity: 'INFO',
      status: 'ACTIVE',
      metadata: { source, audience: 'dashboard_home' },
    })),
  ].slice(0, 6);

  if (generated.length === 0) return;

  await sb
    .from('wealth_insights')
    .update({
      status: 'RESOLVED',
      metadata: {
        source,
        audience: 'dashboard_home',
        replacedAt: new Date().toISOString(),
      },
    })
    .eq('user_id', userId)
    .eq('status', 'ACTIVE')
    .contains('metadata', { audience: 'dashboard_home' });

  await sb.from('wealth_insights').insert(generated);
}

export const registerEngagementRoutes = (v1: Router, deps: Deps) => {
  const { authenticate, upload, LogicCore, getAdminSupabase } = deps;

  v1.post('/chat', authenticate as any, upload.any(), async (req, res) => {
    const { message } = req.body;
    const session = (req as any).session;
    const userId = session.sub;

    if (!message) return res.status(400).json({ success: false, error: 'Message required' });

    try {
      const apiKey = process.env.GEMINI_API_KEY;
      if (!apiKey) throw new Error('GEMINI_API_KEY_MISSING');
      const ai = new GoogleGenAI({ apiKey });

      const sb = getAdminSupabase();
      const { data: user } = await sb!.from('users').select('full_name, email, account_status').eq('id', userId).single();
      const { data: recentActivity } = await sb!
        .from('transactions')
        .select('amount, description, created_at')
        .eq('user_id', userId)
        .order('created_at', { ascending: false })
        .limit(1);

      const context = { user, recentActivity };

      let prompt = `User context: ${JSON.stringify(context)}. User message: ${message}`;
      if (message === 'init') {
        const hour = new Date().getHours();
        const timeOfDay = hour < 12 ? 'morning' : hour < 18 ? 'afternoon' : 'evening';

        prompt = `User context: ${JSON.stringify(context)}. 
            Current time of day: ${timeOfDay}.
            Please provide a warm, professional welcome greeting to the user, ${user?.full_name || 'valued customer'}.
            Use the time of day (${timeOfDay}) in the greeting.
            Mention one of their recent activities from the context if available, or if their account status is not 'active', mention an account issue.
            Ask them how you can help them with Orbi services (payments, savings, corporate).`;
      }

      const systemInstruction = `
            You are the Orbi AI Agent. 
            
            KNOWLEDGE BASE:
            ${JSON.stringify(OrbiKnowledge, null, 2)}
            
            INSTRUCTIONS:
            1. Always use the provided KNOWLEDGE BASE to answer questions about Orbi.
            2. If a user asks about something not in the knowledge base, politely state that you don't have that information.
            3. Use a professional, helpful, and secure tone.
            4. Avoid technical jargon (e.g., 'ledger', 'settlement'); use user-friendly terms (e.g., 'payment', 'account').
            5. If the user provides a document, analyze it specifically for issues related to the Orbi Platform using the KNOWLEDGE BASE.
            6. CRITICAL: Do NOT use the word 'Fynix' or 'fynix'. Always use 'Orbi'.
        `;

      const contents: any = { parts: [{ text: prompt }] };
      const uploadedFile = getFirstUploadedFile(req);
      if (uploadedFile) {
        contents.parts.push({
          inlineData: {
            mimeType: uploadedFile.mimetype,
            data: uploadedFile.buffer.toString('base64'),
          },
        });
      }

      const response = await callGeminiWithRetry(ai, {
        model: uploadedFile ? 'gemini-2.5-flash' : 'gemini-2.5-flash',
        contents,
        config: { systemInstruction },
      });

      if (!response.text) {
        throw new Error('No response text from Gemini');
      }

      res.json({ success: true, data: response.text });
    } catch (e: any) {
      console.error('[Chat] Error:', e);
      res.status(500).json({ success: false, error: e.message });
    }
  });

  v1.get('/insights', authenticate as any, async (req, res) => {
    const session = (req as any).session;
    const userId = session.sub;

    try {
      const sb = getAdminSupabase();
      if (!sb) {
        return res.status(503).json({ success: false, error: 'DB_OFFLINE' });
      }
      const { data: transactions } = await sb
        .from('transactions')
        .select('amount, description, created_at, category')
        .eq('user_id', userId)
        .order('created_at', { ascending: false })
        .limit(20);

      const { data: goals } = await sb
        .from('goals')
        .select('name, target_amount, current_amount, funding_strategy, auto_allocation_enabled, linked_income_percentage, monthly_target')
        .eq('user_id', userId);

      const { data: categories } = await sb
        .from('categories')
        .select('name, budget, spent_amount, hard_limit, period')
        .eq('user_id', userId);

      const { data: billReserves } = await sb
        .from('bill_reserves')
        .select('provider_name, bill_type, reserve_amount, locked_balance, due_pattern, due_day, status, is_active')
        .eq('user_id', userId)
        .neq('status', 'ARCHIVED');

      const storedInsights = await fetchStoredWealthInsights(sb, userId);

      const allocatedToGoals = (goals || []).reduce((sum: number, g: any) => sum + Number(g.current_amount || 0), 0);
      const allocatedToBudgets = (categories || []).reduce((sum: number, c: any) => sum + Number(c.budget || 0), 0);
      const recentSpend = (transactions || []).reduce((sum: number, t: any) => sum + Number(t.amount || 0), 0);

      const context = {
        transactions,
        goals,
        categories,
        billReserves,
        moneyState: {
          allocatedToGoals,
          allocatedToBudgets,
          totalAllocated: allocatedToGoals + allocatedToBudgets,
          recentObservedSpend: recentSpend,
        },
      };

      const systemInstruction = `
            You are the Orbi Financial Advisor. 
            Analyze the provided transaction history, savings goals, budget allocations, and money-state summary to provide personalized financial advice.
            
            Return the response in the following JSON format:
            {
                "spendingAlerts": ["string"],
                "budgetSuggestions": ["string"],
                "financialAdvice": ["string"]
            }
            
            GUIDELINES:
            - Base all advice ONLY on the provided user activity (transactions, goals, categories, and moneyState).
            - Focus on spending habits, savings progress, budget pressure, allocation discipline, and helpful next steps.
            - Explicitly reason about where money currently sits: available, budgeted, saved, locked, or spent.
            - Prefer concrete behavioral observations over generic advice.
            - Mention weak liquidity, overspending pressure, or over-concentration in allocations when the data supports it.
            - Use a professional, helpful, and secure tone.
            - Avoid technical jargon; use user-friendly terms.
            - CRITICAL: Do NOT use the word 'Fynix' or 'fynix'. Always use 'Orbi'.
        `;

      const heuristicFallback = buildHeuristicInsights({
        transactions: transactions || [],
        goals: goals || [],
        categories: categories || [],
        billReserves: billReserves || [],
      });
      const storedFallback = mapStoredInsightsToPayload(storedInsights);

      let insights: InsightPayload | null = null;
      const apiKey = process.env.GEMINI_API_KEY;
      if (apiKey) {
        try {
          const ai = new GoogleGenAI({ apiKey });
          const response = await callGeminiWithRetry(ai, {
            model: 'gemini-2.5-flash',
            contents: `Analyze this financial data: ${JSON.stringify(context)}`,
            config: {
              systemInstruction,
              responseMimeType: 'application/json',
            },
          });
          insights = parseInsightJson(response.text);
        } catch (e) {
          console.error('[Insights] AI generation failed, using fallback:', e);
        }
      }

      const resolved = insights && (
        insights.spendingAlerts.length ||
        insights.budgetSuggestions.length ||
        insights.financialAdvice.length
      )
        ? insights
        : {
            spendingAlerts: [
              ...storedFallback.spendingAlerts,
              ...heuristicFallback.spendingAlerts,
            ].slice(0, 3),
            budgetSuggestions: [
              ...storedFallback.budgetSuggestions,
              ...heuristicFallback.budgetSuggestions,
            ].slice(0, 3),
            financialAdvice: [
              ...storedFallback.financialAdvice,
              ...heuristicFallback.financialAdvice,
            ].slice(0, 3),
          };

      await upsertGeneratedInsights(sb, userId, resolved, insights ? 'AI' : 'HEURISTIC');

      res.json({ success: true, data: resolved });
    } catch (e: any) {
      console.error('[Insights] Error:', e);
      res.status(500).json({ success: false, error: e.message });
    }
  });

  v1.get('/insights/feed', authenticate as any, async (req, res) => {
    const session = (req as any).session;
    const userId = session.sub;

    try {
      const sb = getAdminSupabase();
      if (!sb) {
        return res.status(503).json({ success: false, error: 'DB_OFFLINE' });
      }

      const storedInsights = await fetchStoredWealthInsights(sb, userId);
      const feed = storedInsights.length > 0
        ? storedInsights.slice(0, 5).map((row) => ({
            type: String(row.insight_type || 'INSIGHT'),
            title: firstNonEmpty(row.title, 'Guardian AI'),
            message: firstNonEmpty(row.message),
            severity: firstNonEmpty(row.severity, 'INFO'),
            severityLabel: pickSeverityLabel(String(row.insight_type || '')),
            createdAt: row.created_at || null,
            metadata: row.metadata || {},
          }))
        : mapPayloadToFeed(buildHeuristicInsights({
            transactions: [],
            goals: [],
            categories: [],
            billReserves: [],
          }));

      res.json({
        success: true,
        data: {
          insights: feed,
        },
      });
    } catch (e: any) {
      console.error('[Insights Feed] Error:', e);
      res.status(500).json({ success: false, error: e.message });
    }
  });

  v1.get('/insights/merchant-recommendations', authenticate as any, async (req, res) => {
    const session = (req as any).session;
    const userId = session.sub;

    try {
      const sb = getAdminSupabase();
      if (!sb) {
        return res.status(503).json({ success: false, error: 'DB_OFFLINE' });
      }

      const [
        recentTransactionsResult,
        digitalMerchantsResult,
        merchantsResult,
      ] = await Promise.all([
        sb
          .from('transactions')
          .select('merchant_name,category,description,provider,type,metadata,created_at')
          .eq('user_id', userId)
          .order('created_at', { ascending: false })
          .limit(30),
        sb
          .from('digital_merchants')
          .select('id,name,category,status,metadata,created_at')
          .eq('status', 'ACTIVE')
          .order('created_at', { ascending: false })
          .limit(40),
        sb
          .from('merchants')
          .select('id,business_name,status,metadata,created_at')
          .eq('status', 'active')
          .order('created_at', { ascending: false })
          .limit(40),
      ]);

      const recentTransactions = recentTransactionsResult.data || [];
      const digitalMerchants = digitalMerchantsResult.data || [];
      const merchants = merchantsResult.data || [];

      const categoryFrequency = new Map<string, number>();
      const recentMerchantNames = new Set<string>();
      for (const tx of recentTransactions) {
        const metadata = tx.metadata && typeof tx.metadata === 'object' ? tx.metadata : {};
        const category = firstNonEmpty(
          tx.category,
          tx.provider,
          metadata.category,
          metadata.category_name,
          metadata.categoryName,
          metadata.provider,
          metadata.provider_name,
          metadata.providerName,
          tx.type,
        );
        if (category) {
          const key = category.toLowerCase();
          categoryFrequency.set(key, (categoryFrequency.get(key) || 0) + 1);
        }
        const merchantName = firstNonEmpty(
          tx.merchant_name,
          tx.provider,
          metadata.merchant_name,
          metadata.merchantName,
          metadata.business_name,
          metadata.businessName,
          metadata.provider,
          metadata.provider_name,
          metadata.providerName,
        );
        if (merchantName) {
          recentMerchantNames.add(merchantName.toLowerCase());
        }
      }

      const scored = [
        ...digitalMerchants.map((merchant: any) => ({
          id: merchant.id,
          name: merchant.name,
          category: firstNonEmpty(merchant.category, merchant.metadata?.category, 'General'),
          reason: 'Relevant to your current spending pattern',
          source: 'digital_merchants',
          status: merchant.status,
          score: 0,
        })),
        ...merchants.map((merchant: any) => ({
          id: merchant.id,
          name: merchant.business_name,
          category: firstNonEmpty(merchant.metadata?.category, merchant.metadata?.segment, 'General'),
          reason: 'Active merchant on ORBI',
          source: 'merchants',
          status: merchant.status,
          score: 0,
        })),
      ].map((merchant) => {
        const categoryScore = categoryFrequency.get(String(merchant.category).toLowerCase()) || 0;
        const repeatPenalty = recentMerchantNames.has(String(merchant.name).toLowerCase()) ? -1 : 0;
        return {
          ...merchant,
          score: categoryScore * 3 + repeatPenalty + (merchant.source === 'digital_merchants' ? 1 : 0),
          reason: categoryScore > 0
            ? `Matches your recent ${merchant.category.toLowerCase()} activity`
            : merchant.reason,
        };
      });

      const recommendations = scored
        .sort((a, b) => b.score - a.score || a.name.localeCompare(b.name))
        .slice(0, 6)
        .map(({ score, ...merchant }) => merchant);

      res.json({
        success: true,
        data: {
          recommendations,
        },
      });
    } catch (e: any) {
      console.error('[Merchant Recommendations] Error:', e);
      res.status(500).json({ success: false, error: e.message });
    }
  });

  v1.post('/receipt/scan', authenticate as any, upload.any(), async (req, res) => {
    const uploadedFile = getFirstUploadedFile(req);
    if (!uploadedFile) {
      return res.status(400).json({ success: false, error: 'No receipt image provided' });
    }

    try {
      const apiKey = process.env.GEMINI_API_KEY;
      if (!apiKey) throw new Error('GEMINI_API_KEY_MISSING');
      const ai = new GoogleGenAI({ apiKey });

      const imagePart = {
        inlineData: {
          mimeType: uploadedFile.mimetype,
          data: uploadedFile.buffer.toString('base64'),
        },
      };

      const response = await callGeminiWithRetry(ai, {
        model: 'gemini-2.5-flash',
        contents: { parts: [imagePart, { text: 'Extract the merchant name, total amount, currency, and date from this receipt.' }] },
        config: {
          responseMimeType: 'application/json',
          responseSchema: {
            type: Type.OBJECT,
            properties: {
              merchant: { type: Type.STRING },
              amount: { type: Type.NUMBER },
              currency: { type: Type.STRING },
              date: { type: Type.STRING },
            },
            required: ['merchant', 'amount', 'currency', 'date'],
          },
        },
      });

      const receiptData = JSON.parse(response.text || '{}');
      res.json({ success: true, data: receiptData });
    } catch (e: any) {
      console.error('[ReceiptScan] Error:', e);
      res.status(500).json({ success: false, error: e.message });
    }
  });

  v1.get('/notifications', authenticate as any, async (req, res) => {
    const session = (req as any).session;
    const limit = Number(req.query.limit || 50);
    const offset = Number(req.query.offset || 0);
    try {
      const result = await LogicCore.getUserMessages(session.sub, limit, offset);
      res.json({ success: true, data: result });
    } catch (e: any) {
      res.status(500).json({ success: false, error: e.message });
    }
  });

  v1.patch('/notifications/:id/read', authenticate as any, async (req, res) => {
    const session = (req as any).session;
    try {
      await LogicCore.markMessageRead(session.sub, req.params.id);
      res.json({ success: true });
    } catch (e: any) {
      res.status(500).json({ success: false, error: e.message });
    }
  });

  v1.patch('/notifications/read-all', authenticate as any, async (req, res) => {
    const session = (req as any).session;
    try {
      await LogicCore.markAllMessagesRead(session.sub);
      res.json({ success: true });
    } catch (e: any) {
      res.status(500).json({ success: false, error: e.message });
    }
  });

  v1.delete('/notifications/:id', authenticate as any, async (req, res) => {
    const session = (req as any).session;
    try {
      await LogicCore.deleteMessage(session.sub, req.params.id);
      res.json({ success: true });
    } catch (e: any) {
      res.status(500).json({ success: false, error: e.message });
    }
  });
};
