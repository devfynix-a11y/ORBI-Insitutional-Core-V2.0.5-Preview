import { type RequestHandler, type Router } from 'express';

type Deps = {
  authenticate: RequestHandler;
  validate: (schema: any) => RequestHandler;
  LogicCore: any;
  OTPService: any;
  getSupabase: () => any;
  getAdminSupabase: () => any;
  GoalCreateSchema: any;
  GoalUpdateSchema: any;
};

const categoryIdOf = (category: any): string => String(category?.id || category?.category_id || '').trim();

const normalizeBudgetPeriod = (raw: any): string => {
  const value = String(raw || 'MONTHLY').trim().toUpperCase();
  if (['WEEK', 'WEEKLY'].includes(value)) return 'WEEKLY';
  if (['YEAR', 'YEARLY', 'ANNUAL'].includes(value)) return 'ANNUAL';
  if (['QUARTER', 'QUARTERLY'].includes(value)) return 'QUARTERLY';
  return 'MONTHLY';
};

const budgetPeriodStart = (raw: any): string => {
  const now = new Date();
  const start = new Date(now);
  start.setHours(0, 0, 0, 0);
  const period = normalizeBudgetPeriod(raw);
  if (period === 'WEEKLY') {
    const day = start.getDay();
    start.setDate(start.getDate() + (day === 0 ? -6 : 1 - day));
  } else if (period === 'QUARTERLY') {
    start.setMonth(Math.floor(start.getMonth() / 3) * 3, 1);
  } else if (period === 'ANNUAL') {
    start.setMonth(0, 1);
  } else {
    start.setDate(1);
  }
  return start.toISOString();
};

const sameBudgetPeriod = (left: any, right: any): boolean => {
  if (!left || !right) return false;
  return new Date(left).getTime() === new Date(right).getTime();
};

const attachBudgetSnapshots = async (sb: any, categories: any[]): Promise<any[]> => {
  if (!sb || !Array.isArray(categories) || categories.length === 0) return categories;
  const categoryIds = Array.from(new Set(categories.map(categoryIdOf).filter(Boolean)));
  if (categoryIds.length === 0) return categories;

  const { data, error } = await sb
    .from('financial_events')
    .select('aggregate_id,payload,created_at')
    .eq('event_type', 'BUDGET_BUCKET_UPDATED')
    .in('aggregate_id', categoryIds)
    .order('created_at', { ascending: false });
  if (error) throw new Error(error.message);

  const snapshotByCategory = new Map<string, any>();
  for (const row of data || []) {
    const categoryId = String(row?.aggregate_id || row?.payload?.category_id || '').trim();
    if (!categoryId || snapshotByCategory.has(categoryId)) continue;
    snapshotByCategory.set(categoryId, row.payload || {});
  }

  return categories.map((category) => {
    const categoryId = categoryIdOf(category);
    const snapshot = snapshotByCategory.get(categoryId);
    const expectedPeriodStart = budgetPeriodStart(
      category?.period || category?.budget_period || category?.budgetPeriod,
    );
    if (!snapshot || !sameBudgetPeriod(snapshot.period_start, expectedPeriodStart)) {
      return category;
    }
    return {
      ...category,
      spent_amount: snapshot.spent_amount,
      spent: snapshot.spent_amount,
      used: snapshot.spent_amount,
      remaining_amount: snapshot.remaining_amount,
      utilization_ratio: snapshot.utilization_ratio,
      budget_snapshot: snapshot,
    };
  });
};

const extractCategoryList = (result: any): any[] => {
  if (Array.isArray(result)) return result;
  if (Array.isArray(result?.categories)) return result.categories;
  if (Array.isArray(result?.items)) return result.items;
  if (Array.isArray(result?.results)) return result.results;
  if (Array.isArray(result?.data)) return result.data;
  return [];
};

const mergeCategoryList = (result: any, categories: any[]): any => {
  if (Array.isArray(result)) return categories;
  if (Array.isArray(result?.categories)) return { ...result, categories };
  if (Array.isArray(result?.items)) return { ...result, items: categories };
  if (Array.isArray(result?.results)) return { ...result, results: categories };
  if (Array.isArray(result?.data)) return { ...result, data: categories };
  return result;
};

export const registerStrategyRoutes = (v1: Router, deps: Deps) => {
  const {
    authenticate,
    validate,
    LogicCore,
    OTPService,
    getSupabase,
    getAdminSupabase,
    GoalCreateSchema,
    GoalUpdateSchema,
  } = deps;

  v1.post('/goals', authenticate as any, validate(GoalCreateSchema), async (req, res) => {
    const session = (req as any).session;
    const authToken = (req as any).authToken as string | null;
    try {
      const result = await LogicCore.postGoal({ ...req.body, user_id: session.sub }, authToken || undefined);
      res.json({ success: true, data: result?.data ?? result });
    } catch (e: any) {
      res.status(500).json({ success: false, error: e.message });
    }
  });

  v1.get('/goals', authenticate as any, async (req, res) => {
    const session = (req as any).session;
    const authToken = (req as any).authToken as string | null;
    try {
      const result = await LogicCore.getGoals(session.sub, authToken || undefined);
      res.json({ success: true, data: result });
    } catch (e: any) {
      res.status(500).json({ success: false, error: e.message });
    }
  });

  v1.patch('/goals/:id', authenticate as any, validate(GoalUpdateSchema), async (req, res) => {
    const authToken = (req as any).authToken as string | null;
    try {
      const result = await LogicCore.updateGoal({ ...req.body, id: req.params.id }, authToken || undefined);
      res.json({ success: true, data: result?.data ?? result });
    } catch (e: any) {
      res.status(500).json({ success: false, error: e.message });
    }
  });

  v1.delete('/goals/:id', authenticate as any, async (req, res) => {
    const authToken = (req as any).authToken as string | null;
    try {
      const result = await LogicCore.deleteGoal(req.params.id, authToken || undefined);
      res.json({ success: true, data: result });
    } catch (e: any) {
      res.status(500).json({ success: false, error: e.message });
    }
  });

  v1.get('/categories', authenticate as any, async (req, res) => {
    const session = (req as any).session;
    const authToken = (req as any).authToken as string | null;
    try {
      const result = await LogicCore.getCategories(session.sub, authToken || undefined);
      const categories = extractCategoryList(result);
      const enriched = categories.length > 0
        ? await attachBudgetSnapshots(getAdminSupabase() || getSupabase(), categories)
        : categories;
      res.json({ success: true, data: mergeCategoryList(result, enriched) });
    } catch (e: any) {
      res.status(500).json({ success: false, error: e.message });
    }
  });

  v1.post('/categories', authenticate as any, async (req, res) => {
    const session = (req as any).session;
    const authToken = (req as any).authToken as string | null;
    try {
      const result = await LogicCore.postCategory({ ...req.body, user_id: session.sub }, authToken || undefined);
      res.json({ success: true, data: result });
    } catch (e: any) {
      res.status(500).json({ success: false, error: e.message });
    }
  });

  v1.patch('/categories/:id', authenticate as any, async (req, res) => {
    const authToken = (req as any).authToken as string | null;
    try {
      const result = await LogicCore.updateCategory({ ...req.body, id: req.params.id }, authToken || undefined);
      res.json({ success: true, data: result });
    } catch (e: any) {
      res.status(500).json({ success: false, error: e.message });
    }
  });

  v1.delete('/categories/:id', authenticate as any, async (req, res) => {
    const authToken = (req as any).authToken as string | null;
    try {
      const result = await LogicCore.deleteCategory(req.params.id, authToken || undefined);
      res.json({ success: true, data: result });
    } catch (e: any) {
      res.status(500).json({ success: false, error: e.message });
    }
  });

  v1.get('/tasks', authenticate as any, async (req, res) => {
    const session = (req as any).session;
    try {
      const result = await LogicCore.getTasks(session.sub);
      res.json({ success: true, data: result });
    } catch (e: any) {
      res.status(500).json({ success: false, error: e.message });
    }
  });

  v1.post('/tasks', authenticate as any, async (req, res) => {
    const session = (req as any).session;
    try {
      const result = await LogicCore.postTask({ ...req.body, user_id: session.sub });
      res.json({ success: true, data: result });
    } catch (e: any) {
      res.status(500).json({ success: false, error: e.message });
    }
  });

  v1.patch('/tasks/:id', authenticate as any, async (req, res) => {
    try {
      const result = await LogicCore.updateTask({ ...req.body, id: req.params.id });
      res.json({ success: true, data: result });
    } catch (e: any) {
      res.status(500).json({ success: false, error: e.message });
    }
  });

  v1.delete('/tasks/:id', authenticate as any, async (req, res) => {
    try {
      const result = await LogicCore.deleteTask(req.params.id);
      res.json({ success: true, data: result });
    } catch (e: any) {
      res.status(500).json({ success: false, error: e.message });
    }
  });

  v1.post('/goals/:id/allocate', authenticate as any, async (req, res) => {
    const authToken = (req as any).authToken as string | null;
    const { amount, sourceWalletId } = req.body;
    if (!amount) return res.status(400).json({ success: false, error: 'MISSING_PARAMS' });

    try {
      const result = await LogicCore.allocateToGoal(req.params.id, amount, sourceWalletId, authToken || undefined);
      res.json({ success: true, data: result });
    } catch (e: any) {
      res.status(500).json({ success: false, error: e.message });
    }
  });

  v1.post('/goals/:id/withdraw', authenticate as any, async (req, res) => {
    const session = (req as any).session;
    const authToken = (req as any).authToken as string | null;
    const { amount, destinationWalletId, verification } = req.body;
    if (!amount || !destinationWalletId) {
      return res.status(400).json({ success: false, error: 'MISSING_PARAMS' });
    }

    const otpRequestId = verification?.otpRequestId || verification?.requestId || req.body.otpRequestId;
    const otpCode = verification?.otpCode || req.body.otpCode;
    if (!otpRequestId || !otpCode) {
      return res.status(403).json({ success: false, error: 'SECURITY_VERIFICATION_REQUIRED' });
    }

    try {
      const verified = await OTPService.verify(String(otpRequestId), String(otpCode), session.sub);
      if (!verified) {
        return res.status(403).json({ success: false, error: 'SECURITY_VERIFICATION_FAILED' });
      }

      const result = await LogicCore.withdrawFromGoal(
        req.params.id,
        amount,
        destinationWalletId,
        {
          verifiedVia: verification?.verifiedVia || 'otp',
          pinVerified: verification?.pinVerified === true,
          deliveryType: verification?.deliveryType || null,
          otpRequestId: String(otpRequestId),
          otpVerifiedAt: new Date().toISOString(),
          verifiedByUserId: session.sub,
        },
        authToken || undefined,
      );
      res.json({ success: true, data: result });
    } catch (e: any) {
      res.status(500).json({ success: false, error: e.message });
    }
  });

  v1.post('/goals/auto-allocate/replay', authenticate as any, async (req, res) => {
    const session = (req as any).session;
    const authToken = (req as any).authToken as string | null;
    const sourceTransactionId = String(req.body?.sourceTransactionId || '').trim();
    if (!sourceTransactionId) {
      return res.status(400).json({ success: false, error: 'SOURCE_TRANSACTION_REQUIRED' });
    }

    try {
      const result = await LogicCore.replayGoalAutoAllocations(session.sub, sourceTransactionId, authToken || undefined);
      res.json({ success: true, data: result });
    } catch (e: any) {
      res.status(400).json({ success: false, error: e.message });
    }
  });
};
