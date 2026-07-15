ALTER TABLE public.user_messages
  ADD COLUMN IF NOT EXISTS metadata JSONB NOT NULL DEFAULT '{}'::jsonb;

COMMENT ON COLUMN public.user_messages.created_at IS
  'Canonical UTC audit timestamp. User-facing displays must use metadata.audit_time/clientTimeContext timezone context when present.';

COMMENT ON COLUMN public.user_messages.metadata IS
  'Notification audit metadata, including canonical UTC, explicit user/request timezone or UTC offset, and display timestamp context.';

COMMENT ON COLUMN public.users.metadata IS
  'User profile metadata. clientTimeContext stores the explicit registration/request timezone or UTC offset used only for user-facing display resolution; canonical financial audit timestamps remain stored in UTC columns.';
