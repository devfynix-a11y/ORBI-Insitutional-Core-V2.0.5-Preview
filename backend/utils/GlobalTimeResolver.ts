export type TimeContextSource = 'request_timezone' | 'request_offset' | 'profile_timezone' | 'profile_offset' | 'utc';

export interface ResolvedTimeContext {
  canonicalUtc: string;
  displayClock: string;
  displayDateTime: string;
  displayTimestamp: string;
  timeZone: string;
  timeZoneLabel: string;
  offsetMinutes: number;
  source: TimeContextSource;
}

function objectValue(value: any): Record<string, any> {
  return value && typeof value === 'object' && !Array.isArray(value) ? value : {};
}

function firstString(values: any[]): string | null {
  for (const value of values) {
    const text = String(value || '').trim();
    if (text) return text;
  }
  return null;
}

function firstNumber(values: any[]): number | null {
  for (const value of values) {
    const parsed = typeof value === 'number' ? value : Number(value);
    if (Number.isFinite(parsed)) return parsed;
  }
  return null;
}

function safeIso(value: string) {
  const parsed = new Date(value);
  return Number.isNaN(parsed.getTime()) ? new Date().toISOString() : parsed.toISOString();
}

function validIso(value: string | null): string | null {
  if (!value) return null;
  const parsed = new Date(value);
  return Number.isNaN(parsed.getTime()) ? null : parsed.toISOString();
}

function isValidTimeZone(timeZone: string): boolean {
  try {
    new Intl.DateTimeFormat('en-US', { timeZone }).format(new Date());
    return true;
  } catch {
    return false;
  }
}

function labelForTimeZone(date: Date, timeZone: string): string {
  if (timeZone === 'UTC') return 'UTC';
  if (['Africa/Dar_es_Salaam', 'Africa/Nairobi', 'Africa/Kampala'].includes(timeZone)) return 'EAT';
  if (timeZone === 'Africa/Johannesburg') return 'SAST';
  try {
    const parts = new Intl.DateTimeFormat('en-US', { timeZone, timeZoneName: 'short' }).formatToParts(date);
    return parts.find((part) => part.type === 'timeZoneName')?.value || timeZone;
  } catch {
    return timeZone;
  }
}

function offsetLabel(offsetMinutes: number): string {
  if (!Number.isFinite(offsetMinutes) || offsetMinutes === 0) return 'UTC';
  const sign = offsetMinutes < 0 ? '-' : '+';
  const absolute = Math.abs(Math.trunc(offsetMinutes));
  const hours = String(Math.floor(absolute / 60)).padStart(2, '0');
  const minutes = String(absolute % 60).padStart(2, '0');
  return `UTC${sign}${hours}:${minutes}`;
}

function clockWithOffset(date: Date, offsetMinutes: number): string {
  const shifted = new Date(date.getTime() + offsetMinutes * 60_000);
  return `${String(shifted.getUTCHours()).padStart(2, '0')}:${String(shifted.getUTCMinutes()).padStart(2, '0')}`;
}

function dateTimeWithOffset(date: Date, offsetMinutes: number): string {
  const shifted = new Date(date.getTime() + offsetMinutes * 60_000);
  const day = String(shifted.getUTCDate()).padStart(2, '0');
  const month = String(shifted.getUTCMonth() + 1).padStart(2, '0');
  const year = shifted.getUTCFullYear();
  return `${day}/${month}/${year} ${clockWithOffset(date, offsetMinutes)}`;
}

function dateTimeWithTimeZone(date: Date, timeZone: string, locale: string): string {
  return new Intl.DateTimeFormat(locale, {
    year: 'numeric',
    month: '2-digit',
    day: '2-digit',
    hour: '2-digit',
    minute: '2-digit',
    hour12: false,
    timeZone,
  }).format(date);
}

function requestTimeContext(metadata: any): Record<string, any> {
  const meta = objectValue(metadata);
  return {
    ...objectValue(meta.client_time_context),
    ...objectValue(meta.clientTimeContext),
  };
}

export class GlobalTimeResolver {
  static buildClientContextFromRequest(body: any = {}, headers: Record<string, any> = {}) {
    const metadata = objectValue(body.metadata);
    const existing = requestTimeContext(metadata);
    const timestampUtc = firstString([
      existing.request_timestamp_utc,
      existing.requestTimestampUtc,
      body.request_timestamp_utc,
      body.timestamp,
      headers['x-orbi-request-timestamp-utc'],
      headers['x-client-request-timestamp-utc'],
    ]);
    const timezone = firstString([
      existing.timezone,
      existing.timeZone,
      existing.iana_timezone,
      existing.ianaTimeZone,
      body.timezone,
      body.timeZone,
      headers['x-orbi-timezone'],
      headers['x-orbi-timezone-name'],
      headers['x-client-timezone'],
    ]);
    const offsetMinutes = firstNumber([
      existing.timezone_offset_minutes,
      existing.timeZoneOffsetMinutes,
      body.timezone_offset_minutes,
      headers['x-orbi-timezone-offset-minutes'],
      headers['x-client-timezone-offset-minutes'],
    ]);
    const normalized: Record<string, any> = {
      ...(timezone && isValidTimeZone(timezone) ? { timezone } : {}),
      ...(offsetMinutes !== null ? {
        timezone_offset_minutes: offsetMinutes,
        timezone_offset: offsetLabel(offsetMinutes),
      } : {}),
    };
    const explicitTimestamp = validIso(timestampUtc);
    if (explicitTimestamp) {
      normalized.request_timestamp_utc = explicitTimestamp;
    }
    return normalized;
  }

  static attachMetadata(metadata: any = {}, clientContext: Record<string, any> = {}) {
    return {
      ...objectValue(metadata),
      clientTimeContext: {
        ...requestTimeContext(metadata),
        ...clientContext,
      },
    };
  }

  static resolve(args: {
    occurredAtUtc?: string | null;
    metadata?: any;
    profile?: any;
    authUser?: any;
    language?: string;
  }): ResolvedTimeContext {
    const date = new Date(args.occurredAtUtc || new Date().toISOString());
    const safeDate = Number.isNaN(date.getTime()) ? new Date() : date;
    const metadata = objectValue(args.metadata);
    const clientContext = requestTimeContext(metadata);
    const profileMetadata = objectValue(args.profile?.metadata);
    const authMetadata = objectValue(args.authUser?.user_metadata);
    const locale = args.language === 'sw' ? 'sw-TZ' : 'en-US';

    const requestTz = firstString([clientContext.timezone, clientContext.timeZone]);
    if (requestTz && isValidTimeZone(requestTz)) {
      const clock = new Intl.DateTimeFormat(locale, { hour: '2-digit', minute: '2-digit', hour12: false, timeZone: requestTz }).format(safeDate);
      const label = labelForTimeZone(safeDate, requestTz);
      const displayDateTime = `${dateTimeWithTimeZone(safeDate, requestTz, locale)} ${label}`;
      return { canonicalUtc: safeDate.toISOString(), displayClock: clock, displayDateTime, displayTimestamp: `${clock} ${label}`, timeZone: requestTz, timeZoneLabel: label, offsetMinutes: 0, source: 'request_timezone' };
    }

    const requestOffset = firstNumber([clientContext.timezone_offset_minutes, clientContext.timeZoneOffsetMinutes]);
    if (requestOffset !== null) {
      const label = offsetLabel(requestOffset);
      const clock = clockWithOffset(safeDate, requestOffset);
      const displayDateTime = `${dateTimeWithOffset(safeDate, requestOffset)} ${label}`;
      return { canonicalUtc: safeDate.toISOString(), displayClock: clock, displayDateTime, displayTimestamp: `${clock} ${label}`, timeZone: label, timeZoneLabel: label, offsetMinutes: requestOffset, source: 'request_offset' };
    }

    const profileTz = firstString([profileMetadata.timezone, profileMetadata.timeZone, profileMetadata.preferred_timezone, profileMetadata.preferredTimeZone, authMetadata.timezone, authMetadata.timeZone]);
    if (profileTz && isValidTimeZone(profileTz)) {
      const clock = new Intl.DateTimeFormat(locale, { hour: '2-digit', minute: '2-digit', hour12: false, timeZone: profileTz }).format(safeDate);
      const label = labelForTimeZone(safeDate, profileTz);
      const displayDateTime = `${dateTimeWithTimeZone(safeDate, profileTz, locale)} ${label}`;
      return { canonicalUtc: safeDate.toISOString(), displayClock: clock, displayDateTime, displayTimestamp: `${clock} ${label}`, timeZone: profileTz, timeZoneLabel: label, offsetMinutes: 0, source: 'profile_timezone' };
    }

    const profileOffset = firstNumber([profileMetadata.timezone_offset_minutes, profileMetadata.timeZoneOffsetMinutes, authMetadata.timezone_offset_minutes, authMetadata.timeZoneOffsetMinutes]);
    if (profileOffset !== null) {
      const label = offsetLabel(profileOffset);
      const clock = clockWithOffset(safeDate, profileOffset);
      const displayDateTime = `${dateTimeWithOffset(safeDate, profileOffset)} ${label}`;
      return { canonicalUtc: safeDate.toISOString(), displayClock: clock, displayDateTime, displayTimestamp: `${clock} ${label}`, timeZone: label, timeZoneLabel: label, offsetMinutes: profileOffset, source: 'profile_offset' };
    }

    const clock = clockWithOffset(safeDate, 0);
    const displayDateTime = `${dateTimeWithOffset(safeDate, 0)} UTC`;
    return { canonicalUtc: safeDate.toISOString(), displayClock: clock, displayDateTime, displayTimestamp: `${clock} UTC`, timeZone: 'UTC', timeZoneLabel: 'UTC', offsetMinutes: 0, source: 'utc' };
  }
}
