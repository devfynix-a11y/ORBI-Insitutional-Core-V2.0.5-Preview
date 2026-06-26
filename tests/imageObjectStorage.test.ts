import assert from 'node:assert/strict';
import test from 'node:test';
import { ImageObjectStorage } from '../backend/storage/ImageObjectStorage.js';

const withR2Env = (run: () => void) => {
  const previous = {
    endpoint: process.env.CLOUDFLARE_R2_ENDPOINT,
    accessKey: process.env.CLOUDFLARE_R2_ACCESS_KEY_ID,
    secret: process.env.CLOUDFLARE_R2_SECRET_ACCESS_KEY,
    bucket: process.env.CLOUDFLARE_R2_IMAGE_BUCKET,
    publicBase: process.env.ORBI_IMAGE_PUBLIC_BASE_URL,
    accountId: process.env.CLOUDFLARE_ACCOUNT_ID,
    aliasAccessKey: process.env.CLOUDFLARE_ACCESS_KEY_ID,
    aliasSecret: process.env.CLOUDFLARE_SECRET_ACCESS_KEY,
    aliasBucket: process.env.CLOUDFLARE_BUCKET_NAME,
    aliasPublicBase: process.env.CLOUDFLARE_PUBLIC_URL_PREFIX,
  };

  process.env.CLOUDFLARE_R2_ENDPOINT = 'https://example.r2.cloudflarestorage.com';
  process.env.CLOUDFLARE_R2_ACCESS_KEY_ID = 'test-key';
  process.env.CLOUDFLARE_R2_SECRET_ACCESS_KEY = 'test-secret';
  process.env.CLOUDFLARE_R2_IMAGE_BUCKET = 'orbi-images';
  process.env.ORBI_IMAGE_PUBLIC_BASE_URL = 'https://images.orbifinancial.com';

  try {
    run();
  } finally {
    const restore = (key: string, value: string | undefined) => {
      if (value === undefined) delete process.env[key];
      else process.env[key] = value;
    };
    restore('CLOUDFLARE_R2_ENDPOINT', previous.endpoint);
    restore('CLOUDFLARE_R2_ACCESS_KEY_ID', previous.accessKey);
    restore('CLOUDFLARE_R2_SECRET_ACCESS_KEY', previous.secret);
    restore('CLOUDFLARE_R2_IMAGE_BUCKET', previous.bucket);
    restore('ORBI_IMAGE_PUBLIC_BASE_URL', previous.publicBase);
    restore('CLOUDFLARE_ACCOUNT_ID', previous.accountId);
    restore('CLOUDFLARE_ACCESS_KEY_ID', previous.aliasAccessKey);
    restore('CLOUDFLARE_SECRET_ACCESS_KEY', previous.aliasSecret);
    restore('CLOUDFLARE_BUCKET_NAME', previous.aliasBucket);
    restore('CLOUDFLARE_PUBLIC_URL_PREFIX', previous.aliasPublicBase);
  }
};

test('R2 image storage accepts the ORBI Cloudflare variable names', () => {
  const previous = {
    endpoint: process.env.CLOUDFLARE_R2_ENDPOINT,
    accessKey: process.env.CLOUDFLARE_R2_ACCESS_KEY_ID,
    secret: process.env.CLOUDFLARE_R2_SECRET_ACCESS_KEY,
    bucket: process.env.CLOUDFLARE_R2_IMAGE_BUCKET,
    publicBase: process.env.ORBI_IMAGE_PUBLIC_BASE_URL,
  };
  delete process.env.CLOUDFLARE_R2_ENDPOINT;
  delete process.env.CLOUDFLARE_R2_ACCESS_KEY_ID;
  delete process.env.CLOUDFLARE_R2_SECRET_ACCESS_KEY;
  delete process.env.CLOUDFLARE_R2_IMAGE_BUCKET;
  delete process.env.ORBI_IMAGE_PUBLIC_BASE_URL;
  process.env.CLOUDFLARE_ACCOUNT_ID = 'test-account';
  process.env.CLOUDFLARE_ACCESS_KEY_ID = 'test-key';
  process.env.CLOUDFLARE_SECRET_ACCESS_KEY = 'test-secret';
  process.env.CLOUDFLARE_BUCKET_NAME = 'test-bucket';
  process.env.CLOUDFLARE_PUBLIC_URL_PREFIX = 'https://media.example.com';

  try {
    const storage = new ImageObjectStorage();
    assert.equal(
      storage.validateImage(Buffer.from([0xff, 0xd8, 0xff, 0x00]), 'image/jpeg').extension,
      'jpg',
    );
  } finally {
    const restore = (key: string, value: string | undefined) => {
      if (value === undefined) delete process.env[key];
      else process.env[key] = value;
    };
    restore('CLOUDFLARE_R2_ENDPOINT', previous.endpoint);
    restore('CLOUDFLARE_R2_ACCESS_KEY_ID', previous.accessKey);
    restore('CLOUDFLARE_R2_SECRET_ACCESS_KEY', previous.secret);
    restore('CLOUDFLARE_R2_IMAGE_BUCKET', previous.bucket);
    restore('ORBI_IMAGE_PUBLIC_BASE_URL', previous.publicBase);
    delete process.env.CLOUDFLARE_ACCOUNT_ID;
    delete process.env.CLOUDFLARE_ACCESS_KEY_ID;
    delete process.env.CLOUDFLARE_SECRET_ACCESS_KEY;
    delete process.env.CLOUDFLARE_BUCKET_NAME;
    delete process.env.CLOUDFLARE_PUBLIC_URL_PREFIX;
  }
});

test('R2 image storage accepts matching JPEG, PNG, and WEBP signatures', () => {
  withR2Env(() => {
    const storage = new ImageObjectStorage();
    assert.equal(
      storage.validateImage(Buffer.from([0xff, 0xd8, 0xff, 0x00]), 'image/jpeg').extension,
      'jpg',
    );
    assert.equal(
      storage.validateImage(
        Buffer.from([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a]),
        'image/png',
      ).extension,
      'png',
    );
    assert.equal(
      storage.validateImage(Buffer.from('RIFFxxxxWEBP', 'ascii'), 'image/webp').extension,
      'webp',
    );
  });
});

test('R2 image storage rejects mismatched signatures and unsupported formats', () => {
  withR2Env(() => {
    const storage = new ImageObjectStorage();
    assert.throws(
      () => storage.validateImage(Buffer.from('not-a-jpeg'), 'image/jpeg'),
      /IMAGE_SIGNATURE_MISMATCH/,
    );
    assert.throws(
      () => storage.validateImage(Buffer.from('GIF89a'), 'image/gif'),
      /UNSUPPORTED_IMAGE_TYPE/,
    );
  });
});
