import { logger } from '../../backend/infrastructure/logger.js';
import type { Server as HttpServer } from 'http';

let shuttingDown = false;

export const isHttpShuttingDown = () => shuttingDown;

const withTimeout = async (promise: Promise<void>, ms: number, label: string) => {
  let timeoutHandle: NodeJS.Timeout | null = null;

  const timeoutPromise = new Promise<void>((_resolve, reject) => {
    timeoutHandle = setTimeout(() => {
      reject(new Error(`${label}_TIMEOUT`));
    }, ms);
  });

  try {
    await Promise.race([promise, timeoutPromise]);
  } finally {
    if (timeoutHandle) {
      clearTimeout(timeoutHandle);
    }
  }
};

export const bootstrapHttp = async ({
  httpServer,
  port,
  onShutdown,
}: {
  httpServer: HttpServer;
  port: number;
  onShutdown?: () => Promise<void>;
}) => {
  await new Promise<void>((resolve) => {
    httpServer.listen(port, '0.0.0.0', () => {
      logger.info('http.server_started', { port });
      resolve();
    });
  });

  const gracefulShutdown = async (signal: string) => {
    if (shuttingDown) {
      logger.warn('http.shutdown_already_in_progress', { signal });
      return;
    }

    shuttingDown = true;
    logger.warn('http.shutdown_signal_received', { signal });

    try {
      await withTimeout(
        new Promise<void>((resolve, reject) => {
          httpServer.close((error) => {
            if (error) {
              reject(error);
              return;
            }

            logger.info('http.server_stopped');
            resolve();
          });
        }),
        Number(process.env.ORBI_HTTP_CLOSE_TIMEOUT_MS || 30000),
        'http_server_close',
      );

      if (onShutdown) {
        await withTimeout(
          onShutdown(),
          Number(process.env.ORBI_APP_SHUTDOWN_TIMEOUT_MS || 30000),
          'app_shutdown_hooks',
        );
      }

      logger.info('http.shutdown_completed');
      process.exit(0);
    } catch (error: any) {
      logger.error('http.shutdown_failed', { message: error?.message || String(error) });
      process.exit(1);
    }
  };

  process.on('SIGTERM', () => {
    void gracefulShutdown('SIGTERM');
  });

  process.on('SIGINT', () => {
    void gracefulShutdown('SIGINT');
  });
};
