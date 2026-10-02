import { HitaHttp } from '../net/HitaHttp';

export const URL_TODAY_HIT: string = 'https://today.hit.edu.cn/category/10';
export const URL_HOA: string = 'https://hoa.moe/';
export const URL_GRADER: string = 'https://grader.hitsz.edu.cn/home';

const HTTP_UA_PC: string =
  'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/134.0.0.0 Safari/537.36';

export interface CampusNotice {
  id: string;
  title: string;
  source: string;
  date: string;
  url: string;
}

/**
 * 今日哈工大资讯拉取。解析逻辑来自参考工程 BlogService。
 */
export class BlogService {
  static async fetchTodayHitNotices(page: number = 0): Promise<CampusNotice[]> {
    const url: string = page > 0 ? URL_TODAY_HIT + '?page=' + page.toString() : URL_TODAY_HIT;
    try {
      const headers: Record<string, string> = {
        'User-Agent': HTTP_UA_PC,
        'Accept': 'text/html,application/xhtml+xml'
      };
      const resp = await HitaHttp.get(url, headers);
      if (!resp.ok || resp.body.length < 80) {
        return BlogService.fallbackNotices();
      }
      const parsed: CampusNotice[] = BlogService.parseTodayHitHtml(resp.body);
      if (parsed.length === 0) {
        return BlogService.fallbackNotices();
      }
      return parsed;
    } catch (_e) {
      return BlogService.fallbackNotices();
    }
  }

  private static parseTodayHitHtml(html: string): CampusNotice[] {
    const out: CampusNotice[] = [];
    const seen: Map<string, boolean> = new Map<string, boolean>();
    let searchFrom: number = 0;
    while (out.length < 30) {
      const hrefIdx: number = html.indexOf('href="/article/', searchFrom);
      if (hrefIdx < 0) {
        break;
      }
      const q1: number = html.indexOf('"', hrefIdx + 6);
      if (q1 < 0) {
        break;
      }
      const path: string = html.substring(hrefIdx + 6, q1);
      searchFrom = q1 + 1;
      if (path.indexOf('/article/') !== 0) {
        continue;
      }
      const full: string = 'https://today.hit.edu.cn' + path;
      if (seen.get(full) === true) {
        continue;
      }
      const chunk: string = html.substring(q1, Math.min(html.length, q1 + 500));
      const title: string = BlogService.extractTitleNear(chunk);
      if (title.length < 6 || title.indexOf('今日哈工大') >= 0) {
        continue;
      }
      seen.set(full, true);
      const item: CampusNotice = {
        id: 'hit_' + out.length.toString() + '_' + Date.now().toString(),
        title: title,
        source: 'today.hit.edu.cn',
        date: '今日哈工大',
        url: full
      };
      out.push(item);
    }
    return out;
  }

  private static extractTitleNear(chunk: string): string {
    let i: number = 0;
    while (i < chunk.length) {
      const gt: number = chunk.indexOf('>', i);
      if (gt < 0) {
        break;
      }
      const lt: number = chunk.indexOf('<', gt + 1);
      if (lt < 0) {
        break;
      }
      const text: string = chunk.substring(gt + 1, lt).replace(/\s+/g, ' ').trim();
      i = lt;
      if (text.length >= 8 && text.length <= 120) {
        return text;
      }
    }
    return '';
  }

  private static fallbackNotices(): CampusNotice[] {
    const list: CampusNotice[] = [];
    list.push({
      id: 'n_fallback',
      title: '今日哈工大 · 点击打开官网查看最新资讯',
      source: 'today.hit.edu.cn',
      date: '官网',
      url: URL_TODAY_HIT
    });
    return list;
  }
}
