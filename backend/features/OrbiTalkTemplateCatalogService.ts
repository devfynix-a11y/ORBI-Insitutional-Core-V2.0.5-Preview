import { TemplateChannel, TemplateLanguage, MessageType, TemplateName } from '../templates/template_types.js';
import { orbiTalkGatewayService } from '../infrastructure/orbiTalkGatewayService.js';

export type OrbiTalkTemplateCatalogItem = {
  name: TemplateName | string;
  channel: TemplateChannel;
  language: TemplateLanguage | string;
  messageType: MessageType;
  subject?: string;
  body: string;
  variables: string[];
};

export type OrbiTalkTemplateSearchInput = {
  search?: string;
  channel?: TemplateChannel;
  language?: TemplateLanguage;
  messageType?: MessageType;
  limit?: number;
};

class OrbiTalkTemplateCatalogService {
  async listTemplates(input: OrbiTalkTemplateSearchInput = {}): Promise<OrbiTalkTemplateCatalogItem[]> {
    const items = await orbiTalkGatewayService.getTemplateCatalog(input);
    return (items || []).sort((a, b) => {
      const byName = String(a.name).localeCompare(String(b.name));
      if (byName !== 0) return byName;
      const byChannel = String(a.channel).localeCompare(String(b.channel));
      if (byChannel !== 0) return byChannel;
      return String(a.language).localeCompare(String(b.language));
    });
  }

  async getTemplate(name: string, preferred: Omit<OrbiTalkTemplateSearchInput, 'search' | 'limit'> = {}): Promise<OrbiTalkTemplateCatalogItem | null> {
    const items = await this.listTemplates({
      search: name,
      channel: preferred.channel,
      language: preferred.language,
      messageType: preferred.messageType,
      limit: 50,
    });

    const exact = items.find((item) => item.name === name
      && (!preferred.channel || item.channel === preferred.channel)
      && (!preferred.language || item.language === preferred.language)
      && (!preferred.messageType || item.messageType === preferred.messageType));

    if (exact) return exact;
    return items.find((item) => item.name === name) || null;
  }

  renderTemplate(template: OrbiTalkTemplateCatalogItem, variables: Record<string, any> = {}) {
    const replace = (input?: string) => {
      if (!input) return '';
      return input.replace(/\{\{(.*?)\}\}/g, (_match, key) => {
        const normalizedKey = String(key || '').trim();
        const value = normalizedKey.split('.').reduce<any>((acc, part) => {
          if (acc == null) return undefined;
          return acc[part];
        }, variables);
        return value == null ? '' : String(value);
      });
    };

    return {
      subject: replace(template.subject),
      body: replace(template.body),
    };
  }
}

export const orbiTalkTemplateCatalog = new OrbiTalkTemplateCatalogService();
