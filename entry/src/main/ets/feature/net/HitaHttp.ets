import { http } from '@kit.NetworkKit';

export class HitaHttpResult {
  statusCode: number = 0;
  body: string = '';
  ok: boolean = false;
}

/**
 * 资讯与 AI 共用的轻量 HTTP。行为对齐参考工程 HttpService 的 GET / JSON POST。
 */
export class HitaHttp {
  static async get(url: string, headers: Record<string, string>): Promise<HitaHttpResult> {
    return HitaHttp.request(url, http.RequestMethod.GET, '', headers);
  }

  static async postJson(url: string, jsonBody: string, headers: Record<string, string>): Promise<HitaHttpResult> {
    const merged: Record<string, string> = {
      'Content-Type': 'application/json'
    };
    const keys: string[] = Object.keys(headers);
    for (let i: number = 0; i < keys.length; i++) {
      merged[keys[i]] = headers[keys[i]];
    }
    return HitaHttp.request(url, http.RequestMethod.POST, jsonBody, merged);
  }

  private static headerObject(headers: Record<string, string>): Object {
    const o: Record<string, string> = {};
    const keys: string[] = Object.keys(headers);
    for (let i: number = 0; i < keys.length; i++) {
      o[keys[i]] = headers[keys[i]];
    }
    return o;
  }

  private static async request(url: string, method: http.RequestMethod, body: string,
    headers: Record<string, string>): Promise<HitaHttpResult> {
    const httpRequest: http.HttpRequest = http.createHttp();
    const opts: http.HttpRequestOptions = {
      method: method,
      header: HitaHttp.headerObject(headers),
      connectTimeout: 20000,
      readTimeout: 35000,
      expectDataType: http.HttpDataType.STRING
    };
    if (body.length > 0) {
      opts.extraData = body;
    }
    const out: HitaHttpResult = new HitaHttpResult();
    try {
      const resp: http.HttpResponse = await httpRequest.request(url, opts);
      out.statusCode = resp.responseCode;
      out.body = resp.result === undefined || resp.result === null ? '' : String(resp.result);
      out.ok = resp.responseCode >= 200 && resp.responseCode < 300 && out.body.length > 0;
      return out;
    } catch (_e) {
      return out;
    } finally {
      httpRequest.destroy();
    }
  }
}
