-- ORBI hotfix: allow authenticated users to manage their own categories and tasks.
-- Run this on the database that backs the mobile app.

ALTER TABLE public.categories ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.tasks ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users manage own categories" ON public.categories;
CREATE POLICY "Users manage own categories"
ON public.categories
FOR ALL
USING (auth.uid() = user_id)
WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users manage own tasks" ON public.tasks;
CREATE POLICY "Users manage own tasks"
ON public.tasks
FOR ALL
USING (auth.uid() = user_id)
WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "Service role category bypass" ON public.categories;
CREATE POLICY "Service role category bypass"
ON public.categories
FOR ALL TO service_role
USING (true)
WITH CHECK (true);

DROP POLICY IF EXISTS "Service role task bypass" ON public.tasks;
CREATE POLICY "Service role task bypass"
ON public.tasks
FOR ALL TO service_role
USING (true)
WITH CHECK (true);
