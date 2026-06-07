import type { Provider, CliHandlers, RequestContext } from "../types.ts";
import type { AnthropicRequest } from "../../anthropic/schema.ts";

function isAnthropicOAuthToken(key: string): boolean {
  return key.startsWith("sk-ant-oat") || key.startsWith("sk-ant-admin");
}

function getAnthropicKey(ctx: RequestContext): string {
  // If the client passed an explicit API key or Bearer token (e.g. from Claude Code OAuth)
  let key = ctx.headers.get("x-api-key") || ctx.headers.get("authorization");
  if (key?.toLowerCase().startsWith("bearer ")) {
    key = key.slice("bearer ".length);
  }

  // Fallback to environment variable if none provided by client
  key = key || process.env.ANTHROPIC_API_KEY;

  if (!key) {
    throw new Error("Anthropic API key not found. Please log into Claude Code or set ANTHROPIC_API_KEY in your environment.");
  }
  console.log(`[anthropic] Using key: ${key.substring(0, 10)}... (length: ${key.length})`);
  return key;
}

async function forwardToAnthropic(
  path: string,
  body: AnthropicRequest,
  ctx: RequestContext,
): Promise<Response> {
  const log = ctx.childLogger("provider.anthropic");
  const url = `https://api.anthropic.com${path}`;

  const headers = new Headers();
  headers.set("Content-Type", "application/json");

  const originalAuth = ctx.headers.get("authorization");
  const originalApiKey = ctx.headers.get("x-api-key");
  const envKey = process.env.ANTHROPIC_API_KEY;

  log.debug("auth headers received", {
    hasOriginalAuth: !!originalAuth,
    hasOriginalApiKey: !!originalApiKey,
    hasEnvKey: !!envKey,
    originalAuthPrefix: originalAuth ? originalAuth.substring(0, 20) : null,
    originalApiKeyPrefix: originalApiKey ? originalApiKey.substring(0, 10) : null,
  });

  if (envKey) {
    // Explicit API key set on the proxy — use x-api-key auth
    log.debug("using env ANTHROPIC_API_KEY");
    headers.set("x-api-key", envKey);
  } else if (originalAuth) {
    const authValue = originalAuth.toLowerCase().startsWith("bearer ")
      ? originalAuth.slice("bearer ".length)
      : originalAuth;
    const isOAuth = isAnthropicOAuthToken(authValue);
    log.debug("processing authorization header", { authValuePrefix: authValue.substring(0, 15), isOAuth });

    if (isOAuth) {
      // Pro/Max subscription OAuth: send as Bearer + require oauth beta header
      log.debug("forwarding OAuth token as Authorization: Bearer");
      headers.set("authorization", originalAuth);
    } else {
      // Regular API key sent in Authorization header
      log.debug("forwarding authorization header as-is");
      headers.set("authorization", originalAuth);
    }
  } else if (originalApiKey) {
    log.debug("forwarding x-api-key header as-is");
    headers.set("x-api-key", originalApiKey);
  }

  // Forward client identity headers (Anthropic validates these for OAuth)
  for (const h of ["anthropic-version", "anthropic-beta", "x-stainless-os", "x-stainless-lang",
                   "x-stainless-package-version", "x-stainless-runtime",
                   "x-stainless-runtime-version", "x-stainless-arch", "user-agent"]) {
    const v = ctx.headers.get(h);
    if (v) headers.set(h, v);
  }

  // Ensure anthropic-version is present
  if (!headers.has("anthropic-version")) {
    headers.set("anthropic-version", "2023-06-01");
  }

  // Ensure oauth beta flag is present for OAuth tokens
  const authHeader = originalAuth || "";
  const authValue = authHeader.toLowerCase().startsWith("bearer ") ? authHeader.slice("bearer ".length) : authHeader;
  if (isAnthropicOAuthToken(authValue)) {
    const existingBeta = headers.get("anthropic-beta") || "";
    if (!existingBeta.includes("oauth-2025-04-20")) {
      headers.set("anthropic-beta", (existingBeta ? existingBeta + "," : "") + "oauth-2025-04-20");
      log.debug("added oauth-2025-04-20 beta header");
    }
    if (!headers.has("user-agent")) {
      headers.set("user-agent", "claude-cli/2.0 (external, cli)");
    }
  }

  const bodyJson = JSON.stringify(body);

  log.debug("forwarding request to anthropic", { url, model: body.model });

  const resp = await fetch(url, {
    method: "POST",
    headers,
    body: bodyJson,
    signal: ctx.signal,
  });

  if (!resp.ok) {
    const errorBody = await resp.text();
    log.error("upstream error", { status: resp.status, statusText: resp.statusText, body: errorBody });
    return new Response(errorBody, {
      status: resp.status,
      headers: resp.headers,
    });
  }

  return resp;
}

const ALIAS_MAP: Record<string, string> = {
  "haiku": "claude-haiku-4-5-20251001",
  "claude-haiku-4-5": "claude-haiku-4-5-20251001",
  "claude-haiku-4-5-20251001": "claude-haiku-4-5-20251001",
  "sonnet": "claude-sonnet-4-20250514",
  "claude-sonnet-4-6": "claude-sonnet-4-20250514",
  "opus": "claude-opus-4-20250514",
  "claude-opus-4-7": "claude-opus-4-20250514",
  "claude-opus-4-8": "claude-opus-4-20250514",
};

async function handleMessages(body: AnthropicRequest, ctx: RequestContext): Promise<Response> {
  return forwardToAnthropic("/v1/messages", body, ctx);
}

async function handleCountTokens(body: AnthropicRequest, ctx: RequestContext): Promise<Response> {
  return forwardToAnthropic("/v1/messages/count_tokens", body, ctx);
}

const cli: CliHandlers = {
  async status() {
    const key = process.env.ANTHROPIC_API_KEY;
    if (key) {
      console.log(`Authenticated with Anthropic API Key: ${key.slice(0, 7)}...${key.slice(-4)}`);
    } else {
      console.log("Not authenticated (ANTHROPIC_API_KEY is not set)");
    }
  },
  async logout() {
    console.log("Please unset the ANTHROPIC_API_KEY environment variable to log out.");
  },
};

export const anthropicProvider: Provider = {
  name: "anthropic",
  supportedModels: new Set([
    "claude-opus-4-20250514",
    "claude-sonnet-4-20250514",
    "claude-haiku-4-5-20251001",
    "claude-3-5-sonnet-20241022",
    "claude-3-5-haiku-20241022",
    "claude-3-opus-20240229",
    "claude-3-sonnet-20240229",
    "claude-3-haiku-20240307",
    "haiku",
    "claude-haiku-4-5",
    "claude-haiku-4-5-20251001",
    "sonnet",
    "claude-sonnet-4-6",
    "opus",
    "claude-opus-4-7",
    "claude-opus-4-8",
  ]),
  handleMessages,
  handleCountTokens,
  cli,
};
