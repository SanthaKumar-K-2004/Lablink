import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.43.1';
import { getFunctionTimeoutMs, getSupabaseCredentials } from './env.ts';

const DEFAULT_TIMEOUT = getFunctionTimeoutMs();

function createTimeoutFetch(timeoutMs: number) {
  return (resource: RequestInfo | URL, init?: RequestInit) => {
    const controller = new AbortController();
    const timeout = setTimeout(() => controller.abort(), timeoutMs);
    const finalInit: RequestInit = { ...init, signal: controller.signal };

    return fetch(resource, finalInit)
      .finally(() => clearTimeout(timeout));
  };
}

export function createServiceClient() {
  const { url, serviceKey } = getSupabaseCredentials();
  return createClient(url, serviceKey, {
    auth: { persistSession: false, autoRefreshToken: false },
    global: {
      fetch: createTimeoutFetch(DEFAULT_TIMEOUT),
    },
  });
}
