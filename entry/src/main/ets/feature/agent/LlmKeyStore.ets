import { preferences } from '@kit.ArkData';
import { common } from '@kit.AbilityKit';

const STORE_NAME: string = 'hitanext_store';
const KEY_PROVIDER: string = 'llm_provider';
const KEY_API: string = 'llm_api_key';

export class LlmKeyStore {
  private static store: preferences.Preferences | undefined = undefined;

  static async init(context: common.Context): Promise<void> {
    if (LlmKeyStore.store !== undefined) {
      return;
    }
    try {
      LlmKeyStore.store = await preferences.getPreferences(context, { name: STORE_NAME });
    } catch (_e) {
      LlmKeyStore.store = undefined;
    }
  }

  static async getProvider(): Promise<string> {
    return LlmKeyStore.read(KEY_PROVIDER, 'deepseek');
  }

  static async getApiKey(): Promise<string> {
    return LlmKeyStore.read(KEY_API, '');
  }

  static async save(provider: string, apiKey: string): Promise<void> {
    if (LlmKeyStore.store === undefined) {
      return;
    }
    await LlmKeyStore.store.put(KEY_PROVIDER, provider);
    await LlmKeyStore.store.put(KEY_API, apiKey.trim());
    await LlmKeyStore.store.flush();
  }

  private static async read(key: string, fallback: string): Promise<string> {
    if (LlmKeyStore.store === undefined) {
      return fallback;
    }
    try {
      const raw: preferences.ValueType = await LlmKeyStore.store.get(key, fallback);
      return raw === undefined || raw === null ? fallback : String(raw);
    } catch (_e) {
      return fallback;
    }
  }
}
