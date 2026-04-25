import 'dotenv/config';
import { validateStartupDependencies, validateStartupEnvironment } from '../bootstrap/validation.js';
import { createAppContext } from './context.js';
import { buildPublicRouteDeps } from './publicRouteDeps.js';
import { registerAppPublicRoutes } from './registerPublicRoutes.js';
import { registerSystemRoutes } from './registerSystemRoutes.js';
import { validate } from '../middleware/validation/validate.js';
import { authenticate, adminOnly, resolveSessionRole, resolveSessionRegistryType, mapServiceRoleToRegistryType, requireSessionPermission } from '../middleware/auth/sessionAuth.js';
import { ALLOWED_ORIGINS } from '../middleware/security/setup.js';
import { createRuntime } from './runtime.js';
import { continuousSessionMonitor } from '../../backend/src/middleware/session-monitor.middleware.js';
import { tracingMiddleware } from '../../backend/middleware/tracing.js';
import { logger } from '../../backend/infrastructure/logger.js';

validateStartupEnvironment();

const fatalOnStartupDependencyFailure = process.env.NODE_ENV === 'production';

const startupDependenciesReady = validateStartupDependencies()
  .then(() => {
    logger.info('startup.dependencies_validated');
  })
  .catch((error) => {
    logger.error('startup.dependencies_validation_failed', undefined, error);
    if (fatalOnStartupDependencyFailure) {
      throw error;
    }
  });

const { app, httpServer, upload, port: PORT } = createRuntime();

/**
 * ORBI SOVEREIGN GATEWAY (V28.0 Platinum)
 * ---------------------------------------
 * Production-hardened RESTful API with Zod validation and Sentinel AI.
 */

const {
    gatewayBackgroundJobsEnabled,
    legacyApiGatewayEnabled,
    legacyBiometricAliasesEnabled,
    sandboxRoutesEnabled,
    messagingTestRoutesEnabled,
    globalIpLimiter,
} = createAppContext(app);

// Request correlation + session monitoring middleware
for (const mount of ['/api/v1', '/v1']) {
  app.use(mount, tracingMiddleware);
  app.use(mount, continuousSessionMonitor);
}

registerSystemRoutes({
    app,
    authenticate: authenticate as any,
});

registerAppPublicRoutes({
  ...buildPublicRouteDeps({
    app,
    globalIpLimiter: globalIpLimiter as any,
    legacyApiGatewayEnabled,
    legacyBiometricAliasesEnabled,
    messagingTestRoutesEnabled,
    sandboxRoutesEnabled,
    authenticate: authenticate as any,
    adminOnly: adminOnly as any,
    validate,
    requireSessionPermission,
    upload,
    resolveSessionRole,
    resolveSessionRegistryType,
    mapServiceRoleToRegistryType,
  }),
});

export {
  app,
  httpServer,
  PORT,
  gatewayBackgroundJobsEnabled,
  ALLOWED_ORIGINS,
  globalIpLimiter,
  legacyApiGatewayEnabled,
  startupDependenciesReady,
};
