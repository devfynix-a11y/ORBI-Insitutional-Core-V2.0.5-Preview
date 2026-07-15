# ORBI Documentation Index

- `KEYCLOAK_AUTHENTICATION_PLAYBOOK.md`: self-hosted identity, JWT, sessions,
  subject mapping, password recovery, and mobile PKCE migration.

This index defines the canonical ORBI Institutional Core documentation set. Older or narrow documents may remain as compatibility pointers, but new work should update the canonical document for that area first.

## Canonical Documents

| Area | Canonical Document | Purpose |
| :--- | :--- | :--- |
| Business and operating model | [ORBI Business Operational Playbook](./ORBI_BUSINESS_OPERATIONAL_PLAYBOOK.md) | Business model, B2C/B2B/B2B2C operations, merchant/agent/customer flows, operational controls, revenue model, and control-room playbook. |
| Production deployment | [Production Deployment](./PRODUCTION_DEPLOYMENT.md) | Active production deployment requirements, environment variables, TLS, migrations, background workers, rollback, and release automation. |
| System separation | [ORBI System Separation](./ORBI_SYSTEM_SEPARATION.md) | Boundary between ORBI Core, ORBI Pay Gateway, and ORBI Talk Gateway. |
| Environment variables | [Environment Variables Reference](./ENVIRONMENT_VARIABLES_REFERENCE.md) | Complete variable catalog for production and staging environments. |
| Admin portal and SDK | [ORBI Admin Frontend API SDK](./ORBI_ADMIN_FRONTEND_API_SDK.md) | Admin frontend API contract, failover behavior, activity accounting, and SDK usage. |
| Configuration studio | [Admin Config Setup UI Contract](./ADMIN_CONFIG_SETUP_UI_CONTRACT.md) | Provider, FX, routing, fee, and bootstrap configuration contracts. |
| Messaging templates | [ORBI Talk Gateway Templates](./ORBI_TALK_GATEWAY_TEMPLATES.md) | Official ORBI Talk template model, template families, variables, channels, and import guidance. |
| Payment gateway integration | [ORBI Pay Gateway Integration](./ORBI_PAYMENT_GATEWAY_INTEGRATION.md) | Core-side trust boundary for the standalone ORBI Pay Gateway service, callback signing, readiness, and production safety rules. |
| Provider routing | [Provider Registry Contract](./PROVIDER_REGISTRY_CONTRACT.md) | Financial partner registry contract and routing metadata. |
| Provider adapters | [Provider Adapter Architecture](./PROVIDER_ADAPTER_ARCHITECTURE.md) | Provider execution, adapter contracts, retry/failover hooks, and compatibility boundaries. |
| Financial core | [Core Banking Architecture](./CORE_BANKING_ARCHITECTURE.md) | Core ledger, tenants, security, escrow, treasury, messaging, and FX model. |
| Banking engine | [Banking Engine V2](./BANKING_ENGINE_V2.md) | Atomic ledger and TrustBridge architecture details. |
| Transaction movement classification | [Transaction Movement Classification](./TRANSACTION_MOVEMENT_CLASSIFICATION.md) | Canonical movement families/codes for history, reports, receipts, and audit read models without mutating ledger truth. |
| Reconciliation | [Reconciliation Engine](./RECONCILIATION_ENGINE.md) | Financial integrity, reports, admin controls, and reconciliation layers. |
| Disaster recovery | [Disaster Recovery Runbook](./DISASTER_RECOVERY_RUNBOOK.md) | Incident response, severe failure scenarios, recovery objectives, and evidence. |
| Backup restore drill | [Backup Restore Drill Procedure](./BACKUP_RESTORE_DRILL_PROCEDURE.md) | Executable backup restore drill procedure and evidence capture. |
| Release checklist | [Release Checklist](./RELEASE_CHECKLIST.md) | Pre-deploy, smoke, post-deploy, rollback triggers, and evidence. |
| Security simulation | [Security Attack Simulation Plan](./SECURITY_ATTACK_SIMULATION_PLAN.md) | Defensive security validation plan and manual checks. |
| Test plan | [Financial Core Test Plan](./FINANCIAL_CORE_TEST_PLAN.md) | Current test stack, DB integration modes, and priority coverage. |
| Project structure | [Project Structure](./PROJECT_STRUCTURE.md) | Repository layout and ownership of core directories. |

## Merged Compatibility Documents

These files are retained so old links continue to work, but their content has been merged into canonical docs:

| Old Document | Merged Into |
| :--- | :--- |
| [ORBI Operation](./ORBI_OPERATION.md) | [ORBI Business Operational Playbook](./ORBI_BUSINESS_OPERATIONAL_PLAYBOOK.md) |
| [Enterprise B2B Architecture](./ENTERPRISE_B2B_ARCHITECTURE.md) | [ORBI Business Operational Playbook](./ORBI_BUSINESS_OPERATIONAL_PLAYBOOK.md) |
| [Merchant Architecture](./MERCHANT_ARCHITECTURE.md) | [ORBI Business Operational Playbook](./ORBI_BUSINESS_OPERATIONAL_PLAYBOOK.md) |
| [Agent, Merchant, and System Fee Flows](./AGENT_MERCHANT_FEE_FLOWS.md) | [ORBI Business Operational Playbook](./ORBI_BUSINESS_OPERATIONAL_PLAYBOOK.md) |
| [First Backup Restore Drill Plan](./FIRST_BACKUP_RESTORE_DRILL_PLAN.md) | [Backup Restore Drill Procedure](./BACKUP_RESTORE_DRILL_PROCEDURE.md) |
| [Self-Hosted Core and Data Migration](./SELF_HOSTED_DATA_MIGRATION.md) | [Production Deployment](./PRODUCTION_DEPLOYMENT.md) |
| [Self-Hosted Infrastructure Playbook](./SELF_HOSTED_INFRASTRUCTURE_PLAYBOOK.md) | [Release Checklist](./RELEASE_CHECKLIST.md) |
| [ORBI Auth Migration Playbook](./ORBI_AUTH_MIGRATION_PLAYBOOK.md) | [Self-Hosted Core and Data Migration](./SELF_HOSTED_DATA_MIGRATION.md) |
| [Self-Hosted Platform Architecture](./SELF_HOSTED_PLATFORM_ARCHITECTURE.md) | [Self-Hosted Infrastructure Playbook](./SELF_HOSTED_INFRASTRUCTURE_PLAYBOOK.md) |
| [Cloudflare R2 Image Storage](./CLOUDFLARE_R2_IMAGE_STORAGE.md) | [Self-Hosted Platform Architecture](./SELF_HOSTED_PLATFORM_ARCHITECTURE.md) |
| [Frontend Integration Guide](./frontend_integration.md) | [ORBI Admin Frontend API SDK](./ORBI_ADMIN_FRONTEND_API_SDK.md) and [Mobile SDK Guide](./MOBILE_SDK_GUIDE.md) |

## Maintenance Rules

- Keep business and operational policy in the Playbook, not scattered across architecture notes.
- Keep production setup in `PRODUCTION_DEPLOYMENT.md` and data migration controls in `SELF_HOSTED_DATA_MIGRATION.md`.
- Keep API/client integration details in the SDK docs, not in business docs.
- Keep SQL changes documented by migration name when they introduce new business capabilities.
- Do not duplicate ORBI Talk templates under multiple filenames; use `orbi_talk_gateway_templates.json` as the active seed file.
