import { TemplateName } from '../templates/template_types.js';

export type OfficialMessageCategory = 'security' | 'update' | 'promo' | 'info';

export type OfficialMessageTemplateResolution = {
  templateName?: TemplateName;
  variables: Record<string, any>;
  systemCustomBypass: boolean;
};

class OfficialOrbiTalkTemplatePolicy {
  private readonly officialTemplates = new Set<string>([
    'OTP_Message',
    'Welcome_Message',
    'Transfer_Sent',
    'Transfer_Received',
    'Security_Alert_Message',
    'New_Device_Alert',
    'Escrow_Created',
    'Escrow_Request_Received',
    'Escrow_Released',
    'Escrow_Refunded',
    'Salary_Received',
    'Treasury_Withdrawal_Request',
    'Merchant_Service_Update',
    'Agent_Cash_Update',
    'Merchant_Customer_Payment_Update',
    'Agent_Customer_Cash_Update',
    'Agent_Commission_Paid',
    'Service_Customer_Registered',
    'Service_Access_Approved',
    'Shared_Pot_Contribution_Confirmed',
    'Shared_Pot_Contribution_Posted',
    'LOW_BALANCE',
    'Promo_Message',
    'Transactional_Message',
  ]);

  resolve(input: {
    category: OfficialMessageCategory;
    subject: string;
    body: string;
    refId: string;
    template?: string;
    variables?: Record<string, any>;
    systemCustomBypass?: boolean;
  }): OfficialMessageTemplateResolution {
    const baseVariables = {
      refId: input.refId,
      subject: input.subject,
      body: input.body,
      ...(input.variables || {}),
    };

    if (input.template && this.officialTemplates.has(input.template)) {
      return {
        templateName: input.template as TemplateName,
        variables: baseVariables,
        systemCustomBypass: false,
      };
    }

    if (input.systemCustomBypass) {
      return {
        variables: baseVariables,
        systemCustomBypass: true,
      };
    }

    if (input.category === 'security') {
      return {
        templateName: 'Security_Alert_Message',
        variables: baseVariables,
        systemCustomBypass: false,
      };
    }

    if (input.category === 'promo') {
      return {
        templateName: 'Promo_Message',
        variables: {
          body: input.body,
          ...(input.variables || {}),
        },
        systemCustomBypass: false,
      };
    }

    return {
      templateName: 'Transactional_Message',
      variables: {
        body: input.body,
        refId: input.refId,
        ...(input.variables || {}),
      },
      systemCustomBypass: false,
    };
  }
}

export const officialOrbiTalkTemplatePolicy = new OfficialOrbiTalkTemplatePolicy();
