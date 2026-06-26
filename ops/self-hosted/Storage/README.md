# Storage Containers

This module provides private S3-compatible object storage through MinIO.

Buckets created at startup:

- `orbi-assets` for application assets and receipts.
- `orbi-kyc` for restricted identity documents.
- `orbi-backups` for encrypted backup objects.

All buckets are private. The storage API and management console do not publish
host ports in the development stack. Administrative access should use a
temporary SSH tunnel or an internal administration network.

The current application still contains Supabase Storage calls. Starting this
container does not switch those calls automatically. The next storage migration
slice must add an S3 adapter, signed download URLs, retention controls, malware
scanning hooks, and KYC-specific authorization before local storage becomes
authoritative.

For production, replace the default `latest` image variables with tested,
immutable image tags.
