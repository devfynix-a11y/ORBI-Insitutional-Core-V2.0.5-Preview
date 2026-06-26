# Observability

Prometheus scrapes Core's protected operational metrics endpoint over the
private `orbi-ops` network. Grafana and Prometheus bind only to loopback, so
operators must use the VM itself or an SSH/VPN tunnel.

Create the monitor-key file described in `secrets/README.md` before startup.
Alert delivery still requires an Alertmanager module or an external approved
notification target.
