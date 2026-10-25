import { createClient } from "npm:@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};
const json = (body: unknown, status = 200) =>
  new Response(JSON.stringify(body), { status, headers: { ...corsHeaders, "Content-Type": "application/json" } });

const MODEL_ALIASES: Record<string, string> = {
  "gemini-3.8-flash": "gemini-2.5-flash",
  "gemini-3.8-pro": "gemini-2.5-pro",
  "auto-latest": "gemini-2.5-flash",
  "gemini-2.5-flash": "gemini-2.5-flash",
  "gemini-2.5-pro": "gemini-2.5-pro",
  "gemini-2.0-flash": "gemini-2.0-flash",
  "gemini-flash-latest": "gemini-flash-latest",
  "gemini-1.5-flash-latest": "gemini-2.0-flash",
};

function normalizeGenerationConfig(raw: unknown): Record<string, unknown> {
  if (!raw || typeof raw !== "object" || Array.isArray(raw)) return {};
  const input = raw as Record<string, unknown>;
  const output: Record<string, unknown> = {};
  for (const key of ["temperature", "topP", "topK", "maxOutputTokens", "stopSequences", "responseSchema"]) {
    if (input[key] !== undefined) output[key] = input[key];
  }
  const mimeType = input.responseMimeType ?? input.response_mime_type;
  if (typeof mimeType === "string" && mimeType.length <= 80) output.responseMimeType = mimeType;
  return output;
}

Deno.serve(async (request) => {
  if (request.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });
  if (request.method !== "POST") return json({ error: "Method not allowed" }, 405);

  const authorization = request.headers.get("Authorization");
  if (!authorization?.startsWith("Bearer ")) return json({ error: "Authentication required" }, 401);

  const supabaseUrl = Deno.env.get("SUPABASE_URL");
  const anonKey = Deno.env.get("SUPABASE_ANON_KEY");
  const geminiKey = Deno.env.get("GEMINI_API_KEY");
  if (!supabaseUrl || !anonKey) return json({ error: "Auth service is not configured" }, 503);
  if (!geminiKey) return json({ error: "Gemini is not configured on the server" }, 503);

  const supabase = createClient(supabaseUrl, anonKey, {
    global: { headers: { Authorization: authorization } },
    auth: { persistSession: false, autoRefreshToken: false },
  });
  const { data: { user }, error: authError } = await supabase.auth.getUser();
  if (authError || !user) return json({ error: "Invalid or expired session" }, 401);

  let body: Record<string, unknown>;
  try {
    body = await request.json();
  } catch {
    return json({ error: "Invalid JSON body" }, 400);
  }
  const encodedBody = new TextEncoder().encode(JSON.stringify(body));
  if (encodedBody.byteLength > 6_000_000) return json({ error: "Request is too large" }, 413);
  const parts = body.parts;
  if (!Array.isArray(parts) || parts.length < 1 || parts.length > 32) {
    return json({ error: "Invalid Gemini parts" }, 400);
  }
  const requested = typeof body.model === "string" ? body.model : "gemini-2.5-flash";
  const selected = MODEL_ALIASES[requested];
  if (!selected) return json({ error: "Model is not allowed" }, 400);
  const candidates = [...new Set([selected, "gemini-2.5-flash", "gemini-2.0-flash"])].slice(0, 3);
  const generationConfig = normalizeGenerationConfig(body.generationConfig);
  let lastError = "Gemini request failed";

  for (const model of candidates) {
    try {
      const response = await fetch(`https://generativelanguage.googleapis.com/v1beta/models/${model}:generateContent`, {
        method: "POST",
        headers: { "Content-Type": "application/json", "x-goog-api-key": geminiKey },
        body: JSON.stringify({ contents: [{ parts }], generationConfig }),
      });
      const data = await response.json().catch(() => ({}));
      if (response.ok) {
        const text = data?.candidates?.[0]?.content?.parts?.map((part: { text?: string }) => part.text ?? "").join("").trim();
        if (text) return json({ ok: true, model, text, raw: data });
        lastError = "Gemini returned an empty response";
      } else {
        lastError = String(data?.error?.message ?? `Gemini HTTP ${response.status}`).slice(0, 500);
        if (![400, 404, 429, 500, 503].includes(response.status)) break;
      }
    } catch (error) {
      lastError = String(error).slice(0, 500);
    }
  }
  return json({ error: lastError }, 502);
});