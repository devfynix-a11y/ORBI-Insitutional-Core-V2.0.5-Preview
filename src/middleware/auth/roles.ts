export const DOCUMENTED_INSTITUTIONAL_ROLES = [
  'SUPER_ADMIN',
  'ADMIN',
  'IT',
  'AUDIT',
  'ACCOUNTANT',
  'CUSTOMER_CARE',
  'HUMAN_RESOURCE',
] as const;

export const EXTENDED_INSTITUTIONAL_ROLES = [
  'FRAUD',
  'RISK_OFFICER',
  'MARKETING',
] as const;

export const LEGACY_INSTITUTIONAL_ROLE_ALIASES = [
  'STAFF',
] as const;

export const INSTITUTIONAL_ACCESS_ROLES = [
  ...DOCUMENTED_INSTITUTIONAL_ROLES,
  ...EXTENDED_INSTITUTIONAL_ROLES,
  ...LEGACY_INSTITUTIONAL_ROLE_ALIASES,
] as const;

export const ADMIN_ONLY_ROLES = [
  'SUPER_ADMIN',
  'ADMIN',
  'IT',
] as const;

export const SUPER_ADMIN_AND_ADMIN_ROLES = [
  'ADMIN',
  'SUPER_ADMIN',
] as const;

export const TRANSACTION_OVERVIEW_ROLES = [
  'ADMIN',
  'SUPER_ADMIN',
  'AUDIT',
  'CUSTOMER_CARE',
  'ACCOUNTANT',
] as const;

export const TRANSACTION_REVIEW_ROLES = [
  'ADMIN',
  'SUPER_ADMIN',
  'AUDIT',
  'CUSTOMER_CARE',
] as const;

export const AUDIT_DECISION_ROLES = [
  'ADMIN',
  'SUPER_ADMIN',
  'AUDIT',
] as const;

export const DOCUMENT_VERIFICATION_ROLES = [
  'ADMIN',
  'SUPER_ADMIN',
  'CUSTOMER_CARE',
] as const;

export const STAFF_ADMIN_ROLES = [
  'ADMIN',
  'SUPER_ADMIN',
  'HUMAN_RESOURCE',
] as const;

export const STAFF_AUDIT_ROLES = [
  'ADMIN',
  'SUPER_ADMIN',
  'HUMAN_RESOURCE',
  'AUDIT',
] as const;

export const SERVICE_ACCESS_READ_ROLES = [
  'ADMIN',
  'SUPER_ADMIN',
  'CUSTOMER_CARE',
  'AUDIT',
  'HUMAN_RESOURCE',
] as const;

export const SERVICE_ACCESS_REVIEW_ROLES = [
  'ADMIN',
  'SUPER_ADMIN',
  'CUSTOMER_CARE',
  'HUMAN_RESOURCE',
] as const;

export const USER_ADMIN_ROLES = [
  'ADMIN',
  'SUPER_ADMIN',
  'HUMAN_RESOURCE',
] as const;

export const USER_SEARCH_ROLES = [
  'ADMIN',
  'SUPER_ADMIN',
  'CUSTOMER_CARE',
  'AUDIT',
  'HUMAN_RESOURCE',
] as const;

export const RISK_REVIEW_ROLES = [
  'ADMIN',
  'SUPER_ADMIN',
  'AUDIT',
  'IT',
  'RISK_OFFICER',
] as const;

export const STAFF_MESSAGE_READ_ROLES = [
  'ADMIN',
  'SUPER_ADMIN',
  'CUSTOMER_CARE',
  'AUDIT',
  'HUMAN_RESOURCE',
  'IT',
] as const;

export const STAFF_MESSAGE_SEND_ROLES = [
  'ADMIN',
  'SUPER_ADMIN',
  'CUSTOMER_CARE',
  'HUMAN_RESOURCE',
  'IT',
] as const;

export const STAFF_MESSAGE_FLAG_ROLES = [
  'ADMIN',
  'SUPER_ADMIN',
  'CUSTOMER_CARE',
  'AUDIT',
  'IT',
] as const;

export const SUPPORT_TICKET_VIEW_ROLES = [
  'ADMIN',
  'SUPER_ADMIN',
  'CUSTOMER_CARE',
  'AUDIT',
  'HUMAN_RESOURCE',
] as const;

export const SUPPORT_TICKET_MANAGE_ROLES = [
  'ADMIN',
  'SUPER_ADMIN',
  'CUSTOMER_CARE',
  'HUMAN_RESOURCE',
] as const;

export const MARKETING_MESSAGE_ROLES = [
  'ADMIN',
  'SUPER_ADMIN',
  'CUSTOMER_CARE',
  'MARKETING',
  'IT',
] as const;

export const SYSTEM_SMS_ROLES = [
  'ADMIN',
  'SUPER_ADMIN',
  'CUSTOMER_CARE',
  'IT',
] as const;

export const RECONCILIATION_RUN_ROLES = [
  'ADMIN',
  'SUPER_ADMIN',
  'AUDIT',
] as const;

export const RECONCILIATION_REPORT_ROLES = [
  'ADMIN',
  'SUPER_ADMIN',
  'AUDIT',
  'ACCOUNTANT',
] as const;

export const CONFIG_LEDGER_ADMIN_ROLES = [
  'ADMIN',
  'SUPER_ADMIN',
] as const;

export const CONFIG_COMMISSION_VIEW_ROLES = [
  'ADMIN',
  'SUPER_ADMIN',
  'ACCOUNTANT',
] as const;

export const CONFIG_FX_VIEW_ROLES = [
  'ADMIN',
  'SUPER_ADMIN',
  'ACCOUNTANT',
  'IT',
] as const;

export const normalizeRole = (value: unknown, fallback = ''): string =>
  String(value ?? fallback).trim().toUpperCase();

export const isInstitutionalAccessRole = (role: unknown): boolean =>
  INSTITUTIONAL_ACCESS_ROLES.includes(normalizeRole(role) as (typeof INSTITUTIONAL_ACCESS_ROLES)[number]);

export const isAdministrativeRole = (role: unknown): boolean =>
  ADMIN_ONLY_ROLES.includes(normalizeRole(role) as (typeof ADMIN_ONLY_ROLES)[number]);

export const isInstitutionalStaffContext = (role: unknown, registryType: unknown): boolean =>
  normalizeRole(registryType) === 'STAFF' || isInstitutionalAccessRole(role);
