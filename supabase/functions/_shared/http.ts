export function jsonResponse(status: number, data: unknown, headers: HeadersInit = {}): Response {
  const mergedHeaders = new Headers({
    'content-type': 'application/json; charset=utf-8',
    'cache-control': 'no-store',
  });
  const extra = new Headers(headers);
  extra.forEach((value, key) => mergedHeaders.set(key, value));
  return new Response(JSON.stringify(data), { status, headers: mergedHeaders });
}

export function errorResponse(status: number, message: string, details?: Record<string, unknown> | string): Response {
  const payload: Record<string, unknown> = { error: message };
  if (details !== undefined) {
    payload.details = details;
  }
  return jsonResponse(status, payload);
}

export async function parseJsonBody<T>(req: Request): Promise<T> {
  try {
    return await req.json();
  } catch (_error) {
    throw new Error('Invalid or empty JSON body');
  }
}
