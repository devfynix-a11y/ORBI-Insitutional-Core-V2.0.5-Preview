
export const normalizeAndroidHash = (hashStr: string) => {
    if (!hashStr) return hashStr;
    let normalized = hashStr.replace(/-/g, '+').replace(/_/g, '/');
    while (normalized.length % 4) {
        normalized += '=';
    }
    return normalized;
};

export const normalizeAndroidOrigin = (origin: string) => {
    const prefix = 'android:apk-key-hash:';
    if (!origin?.startsWith(prefix)) return origin;
    const rawHash = origin.slice(prefix.length);
    return `${prefix}${normalizeAndroidHash(rawHash)}`;
};

export const sameTrustedOrigin = (actualOrigin: string, expectedOrigin: string) => {
    return (
        normalizeAndroidOrigin(actualOrigin) ===
        normalizeAndroidOrigin(expectedOrigin)
    );
};
