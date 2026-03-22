/**
 * Sends an email using the Brevo API. (DISABLED as per user request)
 */
export async function sendEmail({
    to,
    subject,
    text,
    html,
}: {
    to: string;
    subject: string;
    text?: string;
    html?: string;
}) {
    console.warn(`[MailService] Email sending is DISABLED. Attempted to send to ${to}: ${subject}`);
    return { success: false, message: 'Email service is disabled.' };
}
