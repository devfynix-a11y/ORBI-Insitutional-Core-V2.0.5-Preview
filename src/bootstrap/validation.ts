import { logger } from '../../backend/infrastructure/logger.js';
import { getAdminSupabase, getSupabase } from '../../services/supabaseClient.js';
import fs from 'fs';

const REQUIRED_ENV_PROD = [
  'JWT_SECRET',
  'RP_ID',
  'ORBI_WEB_ORIGIN',
  'ORBI_ANDROID_APP_HASH',
  'ORBI_MOBILE_ORIGIN',
  'KMS_MASTER_KEY',
  'WORKER_SECRET',
  'WORKER_SIGNING_SECRET',
  'ORBI_INTERNAL_MTLS_MODE',
  'SUPABASE_URL',
  'SUPABASE_SERVICE_ROLE_KEY',
  'SUPABASE_ANON_KEY',
  'FIREBASE_SERVICE_ACCOUNT_JSON_BASE64',
];

const OPTIONAL_ENV = [
  'ORBI_MONITOR_API_KEY',
  'ORBI_WEBHOOK_MAX_AGE_SECONDS',
  'ORBI_WEBHOOK_REPLAY_WINDOW_SECONDS',
  'ORBI_PROVIDER_TIMEOUT_MS',
  'ORBI_PROVIDER_MAX_ATTEMPTS',
  'ORBI_PROVIDER_RETRY_DELAY_MS',
  'ORBI_MAX_QUERY_LENGTH',
  'ORBI_MAX_QUERY_PARAMS',
  'ORBI_REQUIRE_API_CONTENT_TYPE',
  'ORBI_REQUIRE_ADMIN_TRACE',
  'ORBI_REQUIRE_ADMIN_DEVICE_ID',
  'ORBI_TALK_GATEWAY_URL',
  'ORBI_TALK_GATEWAY_BASE_URL',
  'ORBI_TALK_GATEWAY_API_KEY',
  'ORBI_TALK_GATEWAY_USER_ID',
  'ORBI_TALK_GATEWAY_USER_EMAIL',
  'ORBI_COMMUNICATIONS_GATEWAY_URL',
  'ORBI_COMMUNICATIONS_GATEWAY_BASE_URL',
  'ORBI_COMMUNICATIONS_GATEWAY_API_KEY',
  'ORBI_COMMUNICATIONS_GATEWAY_USER_ID',
  'ORBI_COMMUNICATIONS_GATEWAY_USER_EMAIL',
  'ORBI_GATEWAY_URL',
  'ORBI_GATEWAY_BASE_URL',
  'ORBI_GATEWAY_API_KEY',
  'ORBI_GATEWAY_USER_ID',
  'ORBI_GATEWAY_USER_EMAIL',
  'OBI_GATEWAY_USER_ID',
  'OBI_GATEWAY_USER_EMAIL',
  'REDIS_CLUSTER_NODES',
  'REDIS_URL',
  'REDIS_HOST',
];

const REQUIRED_RPC_DEPENDENCIES = [
  'post_transaction_v2',
  'append_ledger_entries_v1',
  'claim_internal_transfer_settlement',
  'complete_internal_transfer_settlement',
  'repair_wallet_balance_emergency',
];

const DEFAULT_REQUIRED_PLATFORM_FEE_FLOWS = [
  'CORE_TRANSACTION',
  'EXTERNAL_PAYMENT',
  'WITHDRAWAL',
  'EXTERNAL_TO_INTERNAL',
  'INTERNAL_TO_EXTERNAL',
  'EXTERNAL_TO_EXTERNAL',
  'CARD_SETTLEMENT',
  'GATEWAY_SETTLEMENT',
  'FX_CONVERSION',
  'TENANT_SETTLEMENT_PAYOUT',
  'MERCHANT_PAYMENT',
  'AGENT_CASH_DEPOSIT',
  'AGENT_CASH_WITHDRAWAL',
  'AGENT_REFERRAL_COMMISSION',
  'AGENT_CASH_COMMISSION',
  'SYSTEM_OPERATION',
];

const fatalIfMissing = (key: string) => {
  logger.fatal('startup.missing_required_env', { env_key: key });
  process.exit(1);
};

const warnOptional = (key: string) => {
  logger.warn('startup.missing_optional_env', { env_key: key });
};

const parseCsvEnv = (value: string | undefined, fallback: string[] = []) =>
  String(value || '')
    .split(',')
    .map((item) => item.trim().toUpperCase())
    .filter(Boolean)
    .concat(value ? [] : fallback);

const warnGovernanceConfig = (event: string, payload: Record<string, unknown>) => {
  logger.warn(event, payload);
};

export const validateStartupEnvironment = () => {
  const isProd = process.env.NODE_ENV === 'production';

  for (const key of REQUIRED_ENV_PROD) {
    if (isProd && !process.env[key]) {
      fatalIfMissing(key);
    }
  }

  for (const key of OPTIONAL_ENV) {
    if (!process.env[key]) {
      logger.info('startup.optional_env_unset', { env_key: key });
    }
  }

  if (isProd) {
    const supabaseUrl = String(process.env.SUPABASE_URL || '').trim();
    if (!supabaseUrl.startsWith('https://')) {
      logger.fatal('startup.invalid_supabase_transport', {
        supabase_url: supabaseUrl,
      });
      process.exit(1);
    }

    if (
      process.env.REDIS_TLS_ENABLED === 'true' &&
      process.env.REDIS_ALLOW_INSECURE_TLS === 'true'
    ) {
      logger.fatal('startup.invalid_prod_redis_tls', {
        redis_tls_enabled: process.env.REDIS_TLS_ENABLED,
        redis_allow_insecure_tls: process.env.REDIS_ALLOW_INSECURE_TLS,
      });
      process.exit(1);
    }

    if (process.env.ORBI_ANDROID_APP_HASH && !process.env.ORBI_ANDROID_PACKAGE_NAME) {
      logger.fatal('startup.invalid_android_origin_config', {
        has_android_app_hash: !!process.env.ORBI_ANDROID_APP_HASH,
        has_android_package_name: !!process.env.ORBI_ANDROID_PACKAGE_NAME,
      });
      process.exit(1);
    }

    if (process.env.ORBI_REQUIRE_SIGNED_INTERNAL_REQUESTS === 'false') {
      logger.fatal('startup.invalid_internal_auth_config', {
        require_signed_internal_requests: process.env.ORBI_REQUIRE_SIGNED_INTERNAL_REQUESTS,
      });
      process.exit(1);
    }

    if (process.env.ORBI_ALLOW_LEGACY_INTERNAL_WORKER_AUTH === 'true') {
      logger.fatal('startup.legacy_internal_auth_forbidden', {
        allow_legacy_internal_worker_auth: process.env.ORBI_ALLOW_LEGACY_INTERNAL_WORKER_AUTH,
      });
      process.exit(1);
    }

    if (String(process.env.ORBI_INTERNAL_MTLS_MODE || '').trim().toLowerCase() !== 'required') {
      logger.fatal('startup.invalid_internal_mtls_mode', {
        internal_mtls_mode: process.env.ORBI_INTERNAL_MTLS_MODE,
      });
      process.exit(1);
    }

    const internalMtlsSource = String(process.env.ORBI_INTERNAL_MTLS_SOURCE || 'proxy').trim().toLowerCase();
    if (!['proxy', 'direct'].includes(internalMtlsSource)) {
      logger.fatal('startup.invalid_internal_mtls_source', {
        internal_mtls_source: process.env.ORBI_INTERNAL_MTLS_SOURCE,
      });
      process.exit(1);
    }

    if (internalMtlsSource === 'proxy' && !String(process.env.ORBI_INTERNAL_MTLS_PROXY_SHARED_SECRET || '').trim()) {
      logger.fatal('startup.missing_internal_mtls_proxy_secret', {
        internal_mtls_source: internalMtlsSource,
      });
      process.exit(1);
    }

    if (internalMtlsSource === 'direct' && String(process.env.ORBI_TLS_ENABLED || '').trim().toLowerCase() !== 'true') {
      logger.fatal('startup.invalid_direct_mtls_transport', {
        internal_mtls_source: internalMtlsSource,
        tls_enabled: process.env.ORBI_TLS_ENABLED,
      });
      process.exit(1);
    }

    if (String(process.env.ORBI_ENFORCE_HTTPS || 'true').trim().toLowerCase() === 'false') {
      logger.fatal('startup.https_enforcement_disabled', {
        enforce_https: process.env.ORBI_ENFORCE_HTTPS,
      });
      process.exit(1);
    }
  }

  if (String(process.env.ORBI_TLS_ENABLED || '').trim().toLowerCase() === 'true') {
    const requiredTlsPaths = ['ORBI_TLS_KEY_PATH', 'ORBI_TLS_CERT_PATH'];

    for (const key of requiredTlsPaths) {
      const candidate = String(process.env[key] || '').trim();
      if (!candidate) {
        logger.fatal('startup.missing_tls_file_path', { env_key: key });
        process.exit(1);
      }

      if (!fs.existsSync(candidate)) {
        logger.fatal('startup.tls_file_missing', { env_key: key, path: candidate });
        process.exit(1);
      }
    }

    const caPath = String(process.env.ORBI_TLS_CA_PATH || '').trim();
    if (caPath && !fs.existsSync(caPath)) {
      logger.fatal('startup.tls_file_missing', { env_key: 'ORBI_TLS_CA_PATH', path: caPath });
      process.exit(1);
    }

    if (String(process.env.ORBI_INTERNAL_MTLS_SOURCE || 'proxy').trim().toLowerCase() === 'direct') {
      const internalMtlsCaPath = String(process.env.ORBI_INTERNAL_MTLS_CA_PATH || process.env.ORBI_TLS_CA_PATH || '').trim();
      if (!internalMtlsCaPath) {
        logger.fatal('startup.missing_internal_mtls_ca', {
          env_key: 'ORBI_INTERNAL_MTLS_CA_PATH',
        });
        process.exit(1);
      }
      if (!fs.existsSync(internalMtlsCaPath)) {
        logger.fatal('startup.tls_file_missing', { env_key: 'ORBI_INTERNAL_MTLS_CA_PATH', path: internalMtlsCaPath });
        process.exit(1);
      }
    }
  }
};

const validateProviderSecretDependencies = (isProd: boolean) => {
  const hasLegacyMessagingGatewayKey = Boolean(process.env.ORBI_GATEWAY_API_KEY);
  const hasOrbiTalkGatewayKey = Boolean(
    process.env.ORBI_TALK_GATEWAY_API_KEY ||
    process.env.ORBI_COMMUNICATIONS_GATEWAY_API_KEY ||
    hasLegacyMessagingGatewayKey
  );
  const hasOrbiTalkGatewayUrl = Boolean(
    process.env.ORBI_TALK_GATEWAY_URL ||
    process.env.ORBI_TALK_GATEWAY_BASE_URL ||
    process.env.ORBI_COMMUNICATIONS_GATEWAY_URL ||
    process.env.ORBI_COMMUNICATIONS_GATEWAY_BASE_URL ||
    process.env.ORBI_GATEWAY_URL ||
    (hasLegacyMessagingGatewayKey && process.env.ORBI_GATEWAY_BASE_URL)
  );

  if (hasOrbiTalkGatewayKey !== hasOrbiTalkGatewayUrl) {
    const payload = {
      has_orbi_talk_gateway_key: hasOrbiTalkGatewayKey,
      has_orbi_talk_gateway_url: hasOrbiTalkGatewayUrl,
    };
    if (isProd) {
      logger.fatal('startup.invalid_orbi_talk_gateway_config', payload);
      process.exit(1);
    } else {
      logger.warn('startup.invalid_orbi_talk_gateway_config', payload);
    }
  }

  if (process.env.ORBI_REQUIRE_WEBHOOK_SIGNATURES !== 'false' && process.env.NODE_ENV === 'production') {
    if (process.env.ORBI_ALLOW_PROCESS_LOCAL_WEBHOOK_REPLAY_STORE === 'true') {
      logger.fatal('startup.invalid_webhook_replay_store', {
        allow_local_replay_store: process.env.ORBI_ALLOW_PROCESS_LOCAL_WEBHOOK_REPLAY_STORE,
      });
      process.exit(1);
    }
  }
};

const validateDbDependencies = async (isProd: boolean) => {
  const adminClient = getAdminSupabase();
  const publicClient = getSupabase();

  if (!adminClient || !publicClient) {
    const payload = {
      has_admin_client: !!adminClient,
      has_public_client: !!publicClient,
    };
    if (isProd) {
      logger.fatal('startup.missing_supabase_clients', payload);
      process.exit(1);
    } else {
      logger.warn('startup.missing_supabase_clients', payload);
      return;
    }
  }

  const shouldValidateDb = isProd || process.env.ORBI_VALIDATE_DB_ON_STARTUP === 'true';
  if (!shouldValidateDb || !adminClient) return;

  const timeoutMs = Number(process.env.ORBI_STARTUP_DB_TIMEOUT_MS || 5000);
  const withTimeout = async <T>(promise: PromiseLike<T>, label: string) => {
    const timer = new Promise<T>((_, reject) =>
      setTimeout(() => reject(new Error(`${label}_TIMEOUT`)), timeoutMs),
    );
    return Promise.race([Promise.resolve(promise), timer]);
  };

  try {
    const connectivityPromise = adminClient
      .from('transactions')
      .select('id')
      .limit(1)
      .maybeSingle()
      .then((result) => result);
    await withTimeout(connectivityPromise, 'DB_CONNECTIVITY');
  } catch (error: any) {
    logger.fatal('startup.db_unreachable', { message: error?.message || String(error) });
    process.exit(1);
  }

  await validatePlatformFeeConfigs(adminClient);
  await validateProviderRegistryReadiness(adminClient);

  const shouldValidateRpc = isProd || process.env.ORBI_VALIDATE_RPC_ON_STARTUP === 'true';
  if (!shouldValidateRpc) return;

  const isParameterizedRpcProbeMiss = (message: string) =>
    /without parameters in the schema cache/i.test(message) ||
    /function .* requires/i.test(message) ||
    /invalid input syntax/i.test(message) ||
    /missing required/i.test(message);

  for (const rpcName of REQUIRED_RPC_DEPENDENCIES) {
    try {
      const result = await adminClient.rpc(rpcName as any, {} as any);
      if (result.error && /does not exist|missing function/i.test(String(result.error.message || ''))) {
        logger.fatal('startup.rpc_missing', { rpc: rpcName, message: result.error.message });
        process.exit(1);
      }
      if (result.error) {
        const message = String(result.error.message || '');
        if (isParameterizedRpcProbeMiss(message)) {
          logger.info('startup.rpc_parameterized_probe_skipped', { rpc: rpcName, message });
        } else {
          logger.warn('startup.rpc_probe_error', { rpc: rpcName, message });
        }
      }
    } catch (error: any) {
      const message = String(error?.message || error || '');
      if (/does not exist|missing function/i.test(message)) {
        logger.fatal('startup.rpc_missing', { rpc: rpcName, message });
        process.exit(1);
      }
      if (isParameterizedRpcProbeMiss(message)) {
        logger.info('startup.rpc_parameterized_probe_skipped', { rpc: rpcName, message });
      } else {
        logger.warn('startup.rpc_probe_error', { rpc: rpcName, message });
      }
    }
  }
};

const validatePlatformFeeConfigs = async (adminClient: any) => {
  const requiredFlows = parseCsvEnv(
    process.env.ORBI_REQUIRED_PLATFORM_FEE_FLOWS,
    DEFAULT_REQUIRED_PLATFORM_FEE_FLOWS,
  );
  if (requiredFlows.length === 0) return;

  const { data, error } = await adminClient
    .from('platform_fee_configs')
    .select('flow_code, status')
    .eq('status', 'ACTIVE')
    .in('flow_code', requiredFlows);

  if (error) {
    warnGovernanceConfig('startup.platform_fee_config_check_failed', {
      message: error.message,
      enforcement: 'runtime',
    });
    return;
  }

  const configuredFlows = new Set((data || []).map((row: any) => String(row.flow_code || '').trim().toUpperCase()));
  const missingFlows = requiredFlows.filter((flow) => !configuredFlows.has(flow));
  if (missingFlows.length > 0) {
    warnGovernanceConfig('startup.platform_fee_configs_missing', {
      missing_flows: missingFlows,
      enforcement: 'runtime',
    });
  }
};

const validateProviderRegistryReadiness = async (adminClient: any) => {
  const { data: partners, error } = await adminClient
    .from('financial_partners')
    .select('id, name, status, api_base_url, webhook_secret, provider_metadata, mapping_config')
    .eq('status', 'ACTIVE');

  if (error) {
    warnGovernanceConfig('startup.provider_registry_check_failed', {
      message: error.message,
      enforcement: 'runtime',
    });
    return;
  }

  const activePartners = partners || [];
  if (activePartners.length === 0) {
    warnGovernanceConfig('startup.no_active_financial_partners', {
      enforcement: 'runtime',
    });
    return;
  }

  const { data: routingRules, error: routingError } = await adminClient
    .from('provider_routing_rules')
    .select('provider_id, status')
    .eq('status', 'ACTIVE');

  const routedProviderIds = new Set(
    routingError ? [] : (routingRules || []).map((row: any) => String(row.provider_id || '').trim()).filter(Boolean),
  );

  const readinessFailures = activePartners
    .map((partner: any) => {
      const metadata = partner.provider_metadata && typeof partner.provider_metadata === 'object'
        ? partner.provider_metadata
        : {};
      const registry = partner.mapping_config && typeof partner.mapping_config === 'object'
        ? partner.mapping_config
        : {};
      const operations = registry.operations && typeof registry.operations === 'object'
        ? Object.keys(registry.operations)
        : [];
      const callback = registry.callback && typeof registry.callback === 'object'
        ? registry.callback
        : null;
      const hasBaseUrl =
        Boolean(String(partner.api_base_url || '').trim()) ||
        Boolean(String(registry.service_root || '').trim()) ||
        Boolean(registry.service_roots && Object.keys(registry.service_roots).length > 0);
      const hasWebhookSecret =
        Boolean(String(partner.webhook_secret || '').trim()) ||
        Boolean(String(metadata?.secrets?.webhook_secret || '').trim());

      const missing = [
        !String(metadata.provider_code || '').trim() ? 'provider_metadata.provider_code' : '',
        operations.length === 0 ? 'mapping_config.operations' : '',
        !callback ? 'mapping_config.callback' : '',
        callback && !String(callback.reference_field || '').trim() ? 'mapping_config.callback.reference_field' : '',
        callback && !String(callback.status_field || '').trim() ? 'mapping_config.callback.status_field' : '',
        !hasWebhookSecret ? 'webhook_secret' : '',
        !hasBaseUrl ? 'api_base_url_or_service_root' : '',
        !routedProviderIds.has(String(partner.id)) ? 'provider_routing_rules' : '',
      ].filter(Boolean);

      return missing.length > 0
        ? {
            id: partner.id,
            name: partner.name,
            missing,
          }
        : null;
    })
    .filter(Boolean);

  if (routingError) {
    warnGovernanceConfig('startup.provider_routing_rules_check_failed', {
      message: routingError.message,
      enforcement: 'runtime',
    });
    return;
  }

  if (readinessFailures.length > 0) {
    warnGovernanceConfig('startup.provider_registry_not_ready', {
      providers: readinessFailures,
      enforcement: 'runtime',
    });
  }
};

export const validateStartupDependencies = async () => {
  const isProd = process.env.NODE_ENV === 'production';

  validateProviderSecretDependencies(isProd);
  await validateDbDependencies(isProd);
};
