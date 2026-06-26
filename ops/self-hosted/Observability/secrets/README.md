# Observability Secrets

Create `orbi_monitor_api_key.txt` in this directory with the exact value of
`ORBI_MONITOR_API_KEY`. The file is ignored by Git and should be mode `0600`.

For production, set `ORBI_MONITOR_KEY_FILE` to a root-owned secret file outside
the repository instead.
