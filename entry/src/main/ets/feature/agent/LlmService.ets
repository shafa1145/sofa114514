import { ChatMessage } from './ChatModels';
import { HitaHttp } from '../net/HitaHttp';

interface LlmChatMessage {
  role: string;
  content: string;
}

interface LlmPayload {
  model: string;
  messages: LlmChatMessage[];
  temperature: number;
}

/**
 * 远端模型调用，对齐参考工程 LlmService（DeepSeek / 智谱）。
 * 仅在用户填写 API Key 且本地工具无法回答时使用。
 */
export class LlmService {
  static async chat(provider: string, apiKey: string, history: ChatMessage[]): Promise<ChatMessage | undefined> {
    if (provider === 'bigmodel') {
      return LlmService.complete('https://open.bigmodel.cn/api/paas/v4/chat/completions', 'glm-4-flash', apiKey, history);
    }
    return LlmService.complete('https://api.deepseek.com/chat/completions', 'deepseek-chat', apiKey, history);
  }

  private static async complete(url: string, model: string, apiKey: string,
    history: ChatMessage[]): Promise<ChatMessage | undefined> {
    const messages: LlmChatMessage[] = [{
      role: 'system',
      content: '你是 HITA 的 AI 助手，面向哈尔滨工业大学一校三区学生。回答用中文，不要编造课表与成绩。'
    }];
    for (let i: number = 0; i < history.length; i++) {
      const item: ChatMessage = history[i];
      if (item.role === 'user' || item.role === 'assistant') {
        messages.push({ role: item.role, content: item.content });
      }
    }
    const payload: LlmPayload = {
      model: model,
      messages: messages,
      temperature: 0.3
    };
    const headers: Record<string, string> = {
      'Authorization': 'Bearer ' + apiKey
    };
    const resp = await HitaHttp.postJson(url, JSON.stringify(payload as Object), headers);
    if (!resp.ok) {
      return undefined;
    }
    try {
      const json: Record<string, Object> = JSON.parse(resp.body) as Record<string, Object>;
      const choices: Object[] = json['choices'] as Object[];
      if (choices === undefined || choices.length === 0) {
        return undefined;
      }
      const msg: Record<string, Object> = (choices[0] as Record<string, Object>)['message'] as Record<string, Object>;
      const content: string = msg['content'] === undefined || msg['content'] === null ? '' : String(msg['content']);
      if (content.length === 0) {
        return undefined;
      }
      const assistant: ChatMessage = {
        id: 'a_' + Date.now().toString(),
        role: 'assistant',
        content: content,
        timestamp: Date.now()
      };
      return assistant;
    } catch (_e) {
      return undefined;
    }
  }
}
