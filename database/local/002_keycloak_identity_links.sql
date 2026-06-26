CREATE TABLE IF NOT EXISTS orbi_auth.identity_links (
    provider TEXT NOT NULL,
    provider_subject TEXT NOT NULL,
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    provider_username TEXT,
    provider_email TEXT,
    linked_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    last_authenticated_at TIMESTAMPTZ,
    metadata JSONB NOT NULL DEFAULT '{}'::jsonb,
    PRIMARY KEY (provider, provider_subject),
    UNIQUE (provider, user_id)
);

CREATE INDEX IF NOT EXISTS idx_orbi_identity_links_user
ON orbi_auth.identity_links(user_id);

REVOKE ALL ON orbi_auth.identity_links FROM PUBLIC;
