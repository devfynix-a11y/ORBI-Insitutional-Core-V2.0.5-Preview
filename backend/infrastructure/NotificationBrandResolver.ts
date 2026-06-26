export type NotificationBrand = {
  code: string;
  displayName: string;
  senderEmail?: string;
  replyTo?: string;
  logoUrl?: string;
  source: 'platform' | 'merchant' | 'explicit';
};

export type NotificationBrandContext = {
  brandCode?: string;
  displayName?: string;
  merchantName?: string;
  serviceCode?: string;
  eventCode?: string;
  replyTo?: string;
  logoUrl?: string;
  senderEmail?: string;
};

const clean = (value: unknown): string => String(value || '').trim();
const normalizedCode = (value: unknown): string =>
  clean(value).toUpperCase().replace(/[^A-Z0-9]+/g, '_').replace(/^_+|_+$/g, '');

const isMerchantEvent = (eventCode?: string): boolean =>
  normalizedCode(eventCode).includes('MERCHANT');

const isMerchantPlaceholder = (value: string): boolean =>
  ['merchant', 'merchant desk', 'merchant account', 'unknown merchant']
    .includes(value.toLowerCase());

export const resolveNotificationBrand = (
  context: NotificationBrandContext = {},
): NotificationBrand => {
  const explicitDisplayName = clean(context.displayName);
  if (explicitDisplayName) {
    return {
      code: normalizedCode(context.brandCode) || normalizedCode(explicitDisplayName) || 'CUSTOM',
      displayName: explicitDisplayName,
      senderEmail: clean(context.senderEmail) || undefined,
      replyTo: clean(context.replyTo) || undefined,
      logoUrl: clean(context.logoUrl) || undefined,
      source: 'explicit',
    };
  }

  const merchantName = clean(context.merchantName);
  if (merchantName && !isMerchantPlaceholder(merchantName)) {
    return {
      code: normalizedCode(context.brandCode) || `MERCHANT_${normalizedCode(merchantName) || 'CUSTOM'}`,
      displayName: merchantName,
      senderEmail: clean(context.senderEmail) || undefined,
      replyTo: clean(context.replyTo) || undefined,
      logoUrl: clean(context.logoUrl) || undefined,
      source: 'merchant',
    };
  }

  if (isMerchantEvent(context.eventCode)) {
    throw new Error('MERCHANT_NOTIFICATION_BRAND_REQUIRED');
  }

  return {
    code: normalizedCode(context.brandCode) || 'ORBI_FINANCIAL',
    displayName: clean(process.env.ORBI_PLATFORM_DISPLAY_NAME) || 'ORBI Financial',
    senderEmail: clean(context.senderEmail) || clean(process.env.ORBI_PLATFORM_SENDER_EMAIL) || undefined,
    replyTo: clean(context.replyTo) || clean(process.env.ORBI_PLATFORM_REPLY_TO) || undefined,
    logoUrl: clean(context.logoUrl) || clean(process.env.ORBI_PLATFORM_LOGO_URL) || undefined,
    source: 'platform',
  };
};

export const resolveTemplateNotificationBrand = (
  templateName: string,
  data: Record<string, any> = {},
  explicit?: NotificationBrandContext | NotificationBrand,
): NotificationBrand => {
  if (explicit && 'source' in explicit) return explicit;

  const merchantTemplate = normalizedCode(templateName).includes('MERCHANT');
  return resolveNotificationBrand({
    ...(explicit || {}),
    brandCode: explicit?.brandCode || data.brandCode || data.brand_code,
    displayName: explicit?.displayName || data.brandDisplayName || data.brand_display_name,
    merchantName:
      explicit?.merchantName ||
      data.merchantName ||
      data.merchant_name ||
      data.businessName ||
      data.business_name ||
      (merchantTemplate ? data.actorLabel || data.actor_label : undefined),
    serviceCode: explicit?.serviceCode || data.serviceCode || data.service_code,
    eventCode: explicit?.eventCode || data.eventCode || data.event_code || templateName,
    replyTo: explicit?.replyTo || data.replyTo || data.reply_to,
    logoUrl: explicit?.logoUrl || data.logoUrl || data.logo_url,
    senderEmail:
      explicit?.senderEmail ||
      data.senderEmail ||
      data.sender_email ||
      data.notificationSenderEmail ||
      data.notification_sender_email ||
      data.businessEmail ||
      data.business_email,
  });
};
