import type { Provider, CliHandlers, RequestContext } from "../types.ts";
import type { AnthropicRequest } from "../../anthropic/schema.ts";

function getZaiKey(): string {
  const key = process.env.ZAI_API_KEY ?? process.env.CCP_ZAI_API_KEY;
  if (!key) {
    throw new Error("ZAI_API_KEY is not set. Please set it in your environment.");
  }
  return key;
}

async function forwardToZai(
  path: string,
  body: AnthropicRequest,
  ctx: RequestContext,
): Promise<Response> {
  const key = getZaiKey();
  const url = `https://api.z.ai/api/anthropic${path}`;
  
  const headers = new Headers();
  headers.set("Content-Type", "application/json");
  headers.set("Authorization", `Bearer ${key}`);
  
  const bodyJson = JSON.stringify(body);
  
  const resp = await fetch(url, {
    method: "POST",
    headers,
    body: bodyJson,
    signal: ctx.signal,
  });

  return resp;
}

async function handleMessages(body: AnthropicRequest, ctx: RequestContext): Promise<Response> {
  const model = body.model === "5.1" ? "glm-5.1" : (body.model === "glm-air" ? "glm-4.5-air" : body.model);
  const resolvedBody = { ...body, model };
  
  return forwardToZai("/v1/messages", resolvedBody, ctx);
}

async function handleCountTokens(body: AnthropicRequest, ctx: RequestContext): Promise<Response> {
  const model = body.model === "5.1" ? "glm-5.1" : (body.model === "glm-air" ? "glm-4.5-air" : body.model);
  const resolvedBody = { ...body, model };
  
  return forwardToZai("/v1/messages/count_tokens", resolvedBody, ctx);
}

const cli: CliHandlers = {
  async status() {
    const key = process.env.ZAI_API_KEY ?? process.env.CCP_ZAI_API_KEY;
    if (key) {
      console.log(`Authenticated with Z.AI API Key: ${key.slice(0, 6)}...${key.slice(-4)}`);
    } else {
      console.log("Not authenticated (ZAI_API_KEY is not set)");
    }
  },
  async logout() {
    console.log("Please unset the ZAI_API_KEY environment variable to log out.");
  },
};

export const zaiProvider: Provider = {
  name: "zai",
  supportedModels: new Set(["glm-4-plus", "glm-4-air", "glm-4-airx", "glm-4-long", "glm-4-flash", "glm-5.1", "5.1", "glm-4.6", "glm-air", "glm-4.5-air"]),
  handleMessages,
  handleCountTokens,
  cli,
};
