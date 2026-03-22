
import sanitizeHtml from 'sanitize-html';

/**
 * CONTENT SANITIZATION ENGINE (V1.0)
 * ---------------------------------
 * Protects against XSS by stripping malicious HTML/JS from user input.
 */
export class SanitizerService {
    private static readonly DEFAULT_OPTIONS: sanitizeHtml.IOptions = {
        allowedTags: [], // Strip all tags by default for maximum security
        allowedAttributes: {},
        disallowedTagsMode: 'discard'
    };

    /**
     * Deeply sanitizes an object or string
     */
    public static sanitize<T>(input: T): T {
        if (typeof input === 'string') {
            return sanitizeHtml(input, this.DEFAULT_OPTIONS) as unknown as T;
        }

        if (Array.isArray(input)) {
            return input.map(item => this.sanitize(item)) as unknown as T;
        }

        if (input !== null && typeof input === 'object') {
            const sanitizedObj: any = {};
            for (const [key, value] of Object.entries(input)) {
                sanitizedObj[key] = this.sanitize(value);
            }
            return sanitizedObj as T;
        }

        return input;
    }

    /**
     * Sanitizes specific fields that might contain rich text (if needed in future)
     */
    public static sanitizeRichText(html: string): string {
        return sanitizeHtml(html, {
            allowedTags: ['b', 'i', 'em', 'strong', 'a', 'p', 'br'],
            allowedAttributes: {
                'a': ['href']
            },
            allowedSchemes: ['http', 'https', 'mailto']
        });
    }
}
