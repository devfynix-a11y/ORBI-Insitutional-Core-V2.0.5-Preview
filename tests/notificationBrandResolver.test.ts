import assert from 'node:assert/strict';
import test from 'node:test';
import {
  resolveNotificationBrand,
  resolveTemplateNotificationBrand,
} from '../backend/infrastructure/NotificationBrandResolver.js';

test('system and security notifications use the ORBI Financial platform brand', () => {
  const brand = resolveNotificationBrand({ eventCode: 'SECURITY_ALERT' });
  assert.equal(brand.code, 'ORBI_FINANCIAL');
  assert.equal(brand.displayName, 'ORBI Financial');
  assert.equal(brand.source, 'platform');
});

test('merchant context resolves the business name supplied by the template', () => {
  const brand = resolveNotificationBrand({
    eventCode: 'MERCHANT_CUSTOMER_PAYMENT_COMPLETED',
    merchantName: 'Example Commerce',
  });
  assert.equal(brand.code, 'MERCHANT_EXAMPLE_COMMERCE');
  assert.equal(brand.displayName, 'Example Commerce');
  assert.equal(brand.source, 'merchant');
});

test('ordinary merchants retain their registered business name', () => {
  const brand = resolveNotificationBrand({
    eventCode: 'MERCHANT_PAYMENT_COMPLETED',
    merchantName: 'Kilimanjaro Books',
    senderEmail: 'receipts@kilimanjarobooks.example',
  });
  assert.equal(brand.code, 'MERCHANT_KILIMANJARO_BOOKS');
  assert.equal(brand.displayName, 'Kilimanjaro Books');
  assert.equal(brand.senderEmail, 'receipts@kilimanjarobooks.example');
  assert.equal(brand.source, 'merchant');
});

test('merchant templates resolve vendor sender email from template data', () => {
  const brand = resolveTemplateNotificationBrand('Merchant_Service_Update', {
    businessName: 'Kijiji Supplies',
    notification_sender_email: 'receipts@kijijisupplies.example',
  });
  assert.equal(brand.displayName, 'Kijiji Supplies');
  assert.equal(brand.senderEmail, 'receipts@kijijisupplies.example');
});

test('merchant gateway templates resolve branding from template variables', () => {
  const brand = resolveTemplateNotificationBrand('Merchant_Service_Update', {
    actorLabel: 'Dynamic Business Limited',
  });
  assert.equal(brand.displayName, 'Dynamic Business Limited');
  assert.equal(brand.code, 'MERCHANT_DYNAMIC_BUSINESS_LIMITED');
});

test('merchant notifications fail closed when merchant identity is unresolved', () => {
  assert.throws(
    () => resolveNotificationBrand({ eventCode: 'MERCHANT_PAYMENT_COMPLETED' }),
    /MERCHANT_NOTIFICATION_BRAND_REQUIRED/,
  );
});

test('generic merchant placeholders are not accepted as sender brands', () => {
  assert.throws(
    () => resolveTemplateNotificationBrand('Merchant_Service_Update', {
      actorLabel: 'Merchant desk',
    }),
    /MERCHANT_NOTIFICATION_BRAND_REQUIRED/,
  );
});
