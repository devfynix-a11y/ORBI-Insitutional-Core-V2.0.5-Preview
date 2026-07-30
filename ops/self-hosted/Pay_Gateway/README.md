# ORBI Pay Gateway Self-Hosted Runtime

This compose module runs the live and sandbox ORBI Pay Gateway containers.

## Services

```text
pay-gateway         -> https://pay.orbifinancial.com       -> container port 3100
pay-gateway-sandbox -> https://sandbox-pay.orbifinancial.com -> container port 3101
```

Live and sandbox must use separate env files, separate database URLs, separate
worker signing secrets, separate developer API keys, and separate webhook
secrets.

## mTLS Certificate Mounts

The compose file mounts read-only certificate directories into:

```text
/opt/orbi/mtls
```

Host defaults:

```text
D:/FYNIX/ORBI/SECREATES/ORBI_MTLS
D:/FYNIX/ORBI/SECREATES/ORBI_MTLS_SANDBOX
```

Override them with:

```env
ORBI_PAY_GATEWAY_MTLS_CERT_DIRECTORY=/srv/orbi/secrets/mtls/pay-gateway
ORBI_PAY_GATEWAY_SANDBOX_MTLS_CERT_DIRECTORY=/srv/orbi/secrets/mtls/pay-gateway-sandbox
```

Do not commit certificates or private keys. Keep private keys root-owned or
server-admin-owned and mount the directory read-only.

Before enabling `PAYMENT_GATEWAY_INTERNAL_MTLS_ENABLED=true`, run the gateway
readiness check from the Pay Gateway Backend repository:

```bash
npm run mtls:readiness -- /path/to/pay-gateway.env
```
