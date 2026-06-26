# Backup and Recovery

The initial backup container creates checksummed PostgreSQL custom-format dumps
on a dedicated Docker volume. It does not publish network ports.

This is a development and early staging control, not the final production
recovery design. Production still requires:

- encrypted backup copies outside the primary VM;
- WAL archiving and point-in-time recovery;
- separate backup credentials;
- immutable retention;
- scheduled restore drills and ledger reconciliation;
- documented recovery-point and recovery-time evidence.

Use `docs/BACKUP_RESTORE_DRILL_PROCEDURE.md` for validation. Never treat a
successful backup command as proof of recoverability without restoring it.
