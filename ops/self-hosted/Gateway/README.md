# Gateway

Nginx is the only public container. It publishes ports 80 and 443 and connects
to Core only through `orbi-edge`.

Before startup, place `fullchain.pem` and `privkey.pem` in the configured
`ORBI_TLS_CERT_DIRECTORY`. Keep certificate private keys outside Git.

The gateway provides TLS termination, WebSocket upgrade support, structured
access logs, request and connection limits, HSTS, and upstream keepalive.
Application authorization and financial idempotency remain enforced by Core.
