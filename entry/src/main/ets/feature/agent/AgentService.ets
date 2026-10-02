import { common } from '@kit.AbilityKit';
import { RdbHelper } from '../../common/db/RdbHelper';
import { EasEventItem, EasEventType, EasTimetable, newId } from '../../common/model/timetable/TimetableModels';
import { DOW_FULL, EasTimeTools } from '../../common/util/EasTimeTools';
import { TimetableResolver } from '../timetable/data/TimetableResolver';
import { TimetableSelectionStore } from '../timetable/data/TimetableSelectionStore';
import { URL_GRADER, URL_HOA, URL_TODAY_HIT } from '../news/BlogService';
import { AgentToolCall, AgentToolResult, ChatMessage } from './ChatModels';
import { LlmKeyStore } from './LlmKeyStore';
import { LlmService } from './LlmService';

const DAY_MS: number = 24 * 60 * 60 * 1000;

/**
 * AI Agent：本地工具优先，可选远端模型。
 * 意图识别与回复结构来自参考工程 AgentService，课表读写接到当前应用的 RDB。
 */
export class AgentService {
  static async handleUserMessage(context: common.Context, history: ChatMessage[],
    userText: string): Promise<ChatMessage[]> {
    const out: ChatMessage[] = [];
    out.push({
      id: 'u_' + Date.now().toString(),
      role: 'user',
      content: userText,
      timestamp: Date.now()
    });

    const toolCall: AgentToolCall | undefined = AgentService.inferLocalTool(userText);
    if (toolCall !== undefined) {
      const result: AgentToolResult = await AgentService.executeTool(context, toolCall);
      out.push({
        id: 't_' + Date.now().toString(),
        role: 'tool',
        content: result.text,
        toolName: result.tool,
        timestamp: Date.now()
      });
      out.push({
        id: 'a_' + Date.now().toString(),
        role: 'assistant',
        content: AgentService.formatToolAnswer(result),
        timestamp: Date.now()
      });
      return out;
    }

    await LlmKeyStore.init(context);
    const apiKey: string = await LlmKeyStore.getApiKey();
    const provider: string = await LlmKeyStore.getProvider();
    if (apiKey.length > 0) {
      const prior: ChatMessage[] = [];
      for (let i: number = 0; i < history.length; i++) {
        prior.push(history[i]);
      }
      prior.push(out[0]);
      const llm: ChatMessage | undefined = await LlmService.chat(provider, apiKey, prior);
      if (llm !== undefined) {
        out.push(llm);
        return out;
      }
    }

    out.push({
      id: 'a_' + Date.now().toString(),
      role: 'assistant',
      content: '我已收到：「' + userText + '」\n\n可直接问我：今天课表、明天有什么课、课程或教师、校园资讯。\n如需更强推理，点右上角「模型」填写 DeepSeek 或智谱 API Key。',
      timestamp: Date.now()
    });
    return out;
  }

  private static inferLocalTool(text: string): AgentToolCall | undefined {
    const t: string = text.trim();
    if (t.length === 0) {
      return undefined;
    }
    if (/资讯|通知|新闻|今日哈工大/.test(t)) {
      return { tool: 'web_search', input: { 'query': t } };
    }
    if (/今天|明天|后天|课表|有什么课|安排/.test(t) && !/空教室|自习/.test(t)) {
      let offset: number = 0;
      if (t.indexOf('明天') >= 0) {
        offset = 1;
      } else if (t.indexOf('后天') >= 0) {
        offset = 2;
      } else if (t.indexOf('昨天') >= 0) {
        offset = -1;
      }
      if (/考试|什么时候|哪节|搜索|查找/.test(t) && !/今天|明天|后天/.test(t)) {
        const keyword: string = t.replace(/课表|查询|搜索|一下/g, '').trim();
        return { tool: 'search_timetable', input: { 'keyword': keyword.length > 0 ? keyword : t } };
      }
      return { tool: 'get_timetable', input: { 'date_offset': offset } };
    }
    if (/空教室|自习|哪里有空/.test(t)) {
      return { tool: 'search_empty_classroom', input: { 'query': t } };
    }
    if (/资料|往年题|笔记|HOA|HITCS|薪火/.test(t)) {
      return { tool: 'search_external_resource', input: { 'query': t } };
    }
    if (/老师|教师|主页/.test(t)) {
      const name: string = t.replace(/老师|教师|主页|查一下|搜索/g, '').trim();
      if (name.length > 0) {
        return { tool: 'search_teacher', input: { 'name': name } };
      }
    }
    if (/课程|评价|详情/.test(t)) {
      return { tool: 'search_course', input: { 'query': t } };
    }
    if (/提醒|添加活动|组会/.test(t)) {
      let name: string = t.replace(/提醒|添加活动|组会|一下|帮我|请/g, '').trim();
      if (name.length === 0) {
        name = '提醒事项';
      }
      if (name.length > 24) {
        name = name.substring(0, 24);
      }
      return {
        tool: 'add_activity',
        input: {
          'name': name,
          'day_offset': t.indexOf('明天') >= 0 ? 1 : 0,
          'text': t
        }
      };
    }
    if (/规章|宿舍|食堂|图书馆|培养方案|学分/.test(t)) {
      return { tool: 'rag_search', input: { 'query': t } };
    }
    return undefined;
  }

  private static async executeTool(context: common.Context, call: AgentToolCall): Promise<AgentToolResult> {
    if (call.tool === 'get_timetable') {
      const offset: number = Number(call.input['date_offset'] ?? 0);
      const events: EasEventItem[] = await AgentService.eventsOnOffset(context, offset);
      const label: string = AgentService.dayLabel(offset);
      if (events.length === 0) {
        return { tool: call.tool, ok: true, text: label + ' 暂无课程或活动。' };
      }
      return { tool: call.tool, ok: true, text: label + '\n' + AgentService.formatEvents(events) };
    }
    if (call.tool === 'search_timetable' || call.tool === 'search_course' || call.tool === 'search_teacher') {
      const keyword: string = String(call.input['keyword'] ?? call.input['query'] ?? call.input['name'] ?? '');
      const list: EasEventItem[] = await AgentService.searchEvents(context, keyword, call.tool === 'search_teacher');
      if (list.length === 0) {
        return { tool: call.tool, ok: true, text: '本地课表未找到与「' + keyword + '」相关的安排。' };
      }
      return { tool: call.tool, ok: true, text: AgentService.formatEvents(list) };
    }
    if (call.tool === 'add_activity') {
      return AgentService.addActivity(context, call);
    }
    if (call.tool === 'search_empty_classroom') {
      return {
        tool: call.tool,
        ok: true,
        text: '空教室实时查询尚未接入教务系统。可以先到「更多」里的空教室入口查看，或直接问我今天的课表。'
      };
    }
    if (call.tool === 'search_external_resource') {
      return {
        tool: call.tool,
        ok: true,
        text: '课程资料入口：\n· HOA 课程资料 / 攻略\n  ' + URL_HOA +
          '\n· 成绩服务 grader\n  ' + URL_GRADER +
          '\n· 今日哈工大\n  ' + URL_TODAY_HIT
      };
    }
    if (call.tool === 'web_search') {
      return {
        tool: call.tool,
        ok: true,
        text: '校园资讯可在底部「资讯」查看。官网入口：\n' + URL_TODAY_HIT
      };
    }
    return {
      tool: call.tool,
      ok: true,
      text: '（本地说明）关于「' + String(call.input['query'] ?? '') +
        '」：请结合校区手册与 HOA 经验。正式规章以学校官网为准。'
    };
  }

  private static formatToolAnswer(result: AgentToolResult): string {
    if (!result.ok) {
      return '查询失败：' + result.text;
    }
    return result.text + '\n\n——\n以上结果来自工具「' + result.tool + '」。若还需更细信息，可以继续追问。';
  }

  private static async displayTimetable(context: common.Context): Promise<EasTimetable | undefined> {
    const rdb: RdbHelper = RdbHelper.getInstance();
    await rdb.init(context);
    await TimetableSelectionStore.getInstance().init(context);
    const selectedId: string = await TimetableSelectionStore.getInstance().load();
    if (selectedId.length > 0) {
      const selected: EasTimetable | undefined = await rdb.getTimetableById(selectedId);
      if (selected !== undefined) {
        return selected;
      }
    }
    return TimetableResolver.getForDisplay(rdb);
  }

  private static async eventsOnOffset(context: common.Context, offset: number): Promise<EasEventItem[]> {
    const timetable: EasTimetable | undefined = await AgentService.displayTimetable(context);
    if (timetable === undefined) {
      return [];
    }
    const all: EasEventItem[] = await RdbHelper.getInstance().getEventsOfTimetable(timetable.id);
    const start: Date = new Date();
    start.setHours(0, 0, 0, 0);
    start.setDate(start.getDate() + offset);
    const from: number = start.getTime();
    const to: number = from + DAY_MS;
    const day: EasEventItem[] = [];
    for (let i: number = 0; i < all.length; i++) {
      const event: EasEventItem = all[i];
      if (event.type === EasEventType.TAG) {
        continue;
      }
      if (event.from >= from && event.from < to) {
        day.push(event);
      }
    }
    day.sort((a: EasEventItem, b: EasEventItem): number => a.from - b.from);
    return day;
  }

  private static async searchEvents(context: common.Context, keyword: string,
    teacherOnly: boolean): Promise<EasEventItem[]> {
    const timetable: EasTimetable | undefined = await AgentService.displayTimetable(context);
    if (timetable === undefined || keyword.length === 0) {
      return [];
    }
    const all: EasEventItem[] = await RdbHelper.getInstance().getEventsOfTimetable(timetable.id);
    const needle: string = keyword.toLowerCase();
    const found: EasEventItem[] = [];
    for (let i: number = 0; i < all.length; i++) {
      const event: EasEventItem = all[i];
      if (event.type === EasEventType.TAG) {
        continue;
      }
      const hay: string = teacherOnly ? event.teacher : (event.name + ' ' + event.place + ' ' + event.teacher);
      if (hay.toLowerCase().indexOf(needle) >= 0) {
        found.push(event);
        if (found.length >= 12) {
          break;
        }
      }
    }
    return found;
  }

  private static async addActivity(context: common.Context, call: AgentToolCall): Promise<AgentToolResult> {
    const timetable: EasTimetable | undefined = await AgentService.displayTimetable(context);
    if (timetable === undefined) {
      return { tool: call.tool, ok: false, text: '还没有课表，无法写入活动。请先导入或生成课表。' };
    }
    const offset: number = Number(call.input['day_offset'] ?? 0);
    const text: string = String(call.input['text'] ?? '');
    let hour: number = 15;
    let minute: number = 0;
    const matched: RegExpExecArray | undefined = new RegExp('(\\d{1,2})[:：](\\d{2})').exec(text) ?? undefined;
    if (matched !== undefined && matched.length >= 3) {
      hour = Number(matched[1]);
      minute = Number(matched[2]);
    }
    if (hour < 0 || hour > 23 || minute < 0 || minute > 59) {
      hour = 15;
      minute = 0;
    }
    const start: Date = new Date();
    start.setHours(0, 0, 0, 0);
    start.setDate(start.getDate() + offset);
    const event: EasEventItem = new EasEventItem();
    event.id = newId();
    event.type = EasEventType.OTHER;
    event.name = String(call.input['name'] ?? '提醒事项');
    event.place = '';
    event.timetableId = timetable.id;
    event.from = start.getTime() + hour * 60 * 60 * 1000 + minute * 60 * 1000;
    event.to = event.from + 60 * 60 * 1000;
    event.createdAt = Date.now();
    await RdbHelper.getInstance().saveEvent(event);
    return {
      tool: call.tool,
      ok: true,
      text: '已添加活动：' + event.name + ' ' + AgentService.dayLabel(offset) + ' ' +
        EasTimeTools.printTime(event.from) + '-' + EasTimeTools.printTime(event.to)
    };
  }

  private static dayLabel(offset: number): string {
    const start: Date = new Date();
    start.setHours(0, 0, 0, 0);
    start.setDate(start.getDate() + offset);
    const ts: number = start.getTime();
    const prefix: string = offset === 0 ? '今天' : (offset === 1 ? '明天' : (offset === -1 ? '昨天' :
      (offset === 2 ? '后天' : EasTimeTools.printDate(ts))));
    return prefix + ' ' + EasTimeTools.printDate(ts) + ' ' + DOW_FULL[EasTimeTools.getDow(ts)];
  }

  private static formatEvents(events: EasEventItem[]): string {
    const lines: string[] = [];
    for (let i: number = 0; i < events.length; i++) {
      const event: EasEventItem = events[i];
      let line: string = '· ' + EasTimeTools.printDate(event.from) + ' ' + DOW_FULL[event.getDow()] + ' ' +
        EasTimeTools.printTime(event.from) + '-' + EasTimeTools.printTime(event.to) + ' ' + event.name;
      if (event.place.length > 0) {
        line = line + ' @ ' + event.place;
      }
      if (event.teacher.length > 0) {
        line = line + '（' + event.teacher + '）';
      }
      lines.push(line);
    }
    return lines.join('\n');
  }
}
