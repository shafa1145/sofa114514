export type ChatRole = 'user' | 'assistant' | 'tool';

export interface ChatMessage {
  id: string;
  role: ChatRole;
  content: string;
  toolName?: string;
  timestamp: number;
}

export type AgentToolName =
  | 'get_timetable'
  | 'add_activity'
  | 'search_empty_classroom'
  | 'search_course'
  | 'search_external_resource'
  | 'search_teacher'
  | 'search_timetable'
  | 'web_search'
  | 'rag_search';

export interface AgentToolCall {
  tool: AgentToolName;
  input: Record<string, string | number>;
}

export interface AgentToolResult {
  tool: AgentToolName;
  ok: boolean;
  text: string;
}

/** 切换 Dock 时保留当前对话。 */
export class AgentMemory {
  static messages: ChatMessage[] = [];
}
