// FırınNet Akademi worker — iş kuyruğu tüketicisi (Edge Function).
//
// Tetik: pg_cron → academy_cron_tick() → net.http_post (Vault:
// academy_worker_url/key) VEYA elle çağrı. Auth: Bearer ==
// ACADEMY_WORKER_TOKEN (yoksa 503 no_secret — fail-closed).
//
// İş türleri: scan_source (RSS→HTML fallback, koşullu GET, SSRF guard),
// draft (DeepSeek şema-doğrulamalı üretim), publish (idempotent RPC),
// humor_post, maintenance (orkestrasyon). Ağır işler (JS-render/OCR/video)
// v1 kapsam DIŞI — bu erişim isteyen kaynaklar degraded işaretlenir.
//
// Dry-run/kill-switch YAYIN kararları DB RPC'lerinde (server-side);
// worker ayrıca academy_enabled=false iken üretim yapmaz.

// deno-lint-ignore-file no-explicit-any
import { createClient } from "jsr:@supabase/supabase-js@2";
import {
  buildDraftPrompt,
  buildHumorPrompt,
  extractPage,
  isAllowedUrl,
  parseFeed,
  textFingerprint,
  validateDraftOutput,
  validateHumorOutput,
} from "./lib.ts";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL") ?? "";
const SERVICE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ??
  Deno.env.get("EDGE_SERVICE_ROLE_KEY") ?? "";
const WORKER_TOKEN = Deno.env.get("ACADEMY_WORKER_TOKEN") ?? "";
const DEEPSEEK_KEY = Deno.env.get("DEEPSEEK_API_KEY") ?? "";
const DEEPSEEK_MODEL = Deno.env.get("DEEPSEEK_MODEL") ?? "deepseek-flash";
const DEEPSEEK_URL = "https://api.deepseek.com/chat/completions";
const FETCH_TIMEOUT_MS = 15000;
const UA =
  "FirinNetAcademyBot/1.0 (+https://firinnet.app; icerik-takibi)";

function db() {
  return createClient(SUPABASE_URL, SERVICE_KEY);
}

async function cfgInt(c: any, key: string, dflt: number): Promise<number> {
  const { data } = await c.from("app_runtime_config").select("value")
    .eq("key", key).maybeSingle();
  const v = data?.value;
  return typeof v === "number" ? v : dflt;
}
async function cfgBool(c: any, key: string, dflt: boolean): Promise<boolean> {
  const { data } = await c.from("app_runtime_config").select("value")
    .eq("key", key).maybeSingle();
  const v = data?.value;
  return typeof v === "boolean" ? v : dflt;
}

// ── Güvenli fetch: SSRF guard + manuel yönlendirme + boyut sınırı ────
async function safeFetch(
  url: string,
  domain: string,
  headers: Record<string, string> = {},
): Promise<{ status: number; text: string; headers: Headers } | null> {
  let current = url;
  for (let hop = 0; hop < 4; hop++) {
    if (!isAllowedUrl(current, domain)) return null;
    const ctl = new AbortController();
    const t = setTimeout(() => ctl.abort(), FETCH_TIMEOUT_MS);
    let resp: Response;
    try {
      resp = await fetch(current, {
        redirect: "manual",
        signal: ctl.signal,
        headers: { "User-Agent": UA, ...headers },
      });
    } catch (_) {
      clearTimeout(t);
      return null;
    }
    clearTimeout(t);
    if (resp.status >= 300 && resp.status < 400) {
      const loc = resp.headers.get("location");
      await resp.body?.cancel();
      if (!loc) return null;
      current = new URL(loc, current).toString();
      continue;
    }
    const ct = resp.headers.get("content-type") ?? "";
    if (/(image|video|audio|octet-stream|zip)/i.test(ct)) {
      await resp.body?.cancel();
      return { status: resp.status, text: "", headers: resp.headers };
    }
    const buf = await resp.arrayBuffer();
    const text = new TextDecoder().decode(buf.slice(0, 1_500_000));
    return { status: resp.status, text, headers: resp.headers };
  }
  return null;
}

// ── Bütçe kontrolü ───────────────────────────────────────────────────
async function budgetOk(c: any, metric: string, capKey: string,
  dflt: number): Promise<boolean> {
  const cap = await cfgInt(c, capKey, dflt);
  const today = new Date().toISOString().slice(0, 10);
  const { data } = await c.from("academy_usage_daily").select("value")
    .eq("metric", metric).eq("day", today).maybeSingle();
  return (Number(data?.value ?? 0)) < cap;
}
async function incrUsage(c: any, metric: string, delta = 1) {
  await c.rpc("academy_incr_usage", { p_metric: metric, p_delta: delta });
}

// ── DeepSeek ─────────────────────────────────────────────────────────
async function deepseek(
  c: any,
  system: string,
  user: string,
  maxTokens: number,
): Promise<
  { ok: true; content: string; tokensIn: number; tokensOut: number } |
  { ok: false; reason: string }
> {
  if (!DEEPSEEK_KEY) return { ok: false, reason: "no_key" };
  if (!(await budgetOk(c, "llm_requests", "academy_daily_llm_request_cap",
    200))) return { ok: false, reason: "budget_requests" };
  if (!(await budgetOk(c, "llm_tokens", "academy_daily_llm_token_cap",
    400000))) return { ok: false, reason: "budget_tokens" };
  const ctl = new AbortController();
  const t = setTimeout(() => ctl.abort(), 60000);
  let resp: Response;
  try {
    resp = await fetch(DEEPSEEK_URL, {
      method: "POST",
      signal: ctl.signal,
      headers: {
        "Content-Type": "application/json",
        Authorization: `Bearer ${DEEPSEEK_KEY}`,
      },
      body: JSON.stringify({
        model: DEEPSEEK_MODEL,
        messages: [
          { role: "system", content: system },
          { role: "user", content: user },
        ],
        response_format: { type: "json_object" },
        max_tokens: maxTokens,
        temperature: 0.7,
      }),
    });
  } catch (_) {
    clearTimeout(t);
    return { ok: false, reason: "network" };
  }
  clearTimeout(t);
  await incrUsage(c, "llm_requests", 1);
  if (resp.status === 429) return { ok: false, reason: "rate_limited" };
  if (!resp.ok) return { ok: false, reason: `http_${resp.status}` };
  let j: any;
  try {
    j = await resp.json();
  } catch (_) {
    return { ok: false, reason: "bad_response_json" };
  }
  const content = j?.choices?.[0]?.message?.content;
  const tokensIn = Number(j?.usage?.prompt_tokens ?? 0);
  const tokensOut = Number(j?.usage?.completion_tokens ?? 0);
  await incrUsage(c, "llm_tokens", tokensIn + tokensOut);
  if (typeof content !== "string" || content.trim() === "") {
    return { ok: false, reason: "empty_content" };
  }
  return { ok: true, content, tokensIn, tokensOut };
}

// ── İş işleyicileri ──────────────────────────────────────────────────
async function handleScanSource(c: any, payload: any): Promise<string> {
  const { data: src } = await c.from("academy_sources").select("*")
    .eq("id", payload.source_id).maybeSingle();
  if (!src) return "source_not_found";
  if (!["candidate", "active", "degraded"].includes(src.status)) {
    return "source_" + src.status;
  }
  if (!(await budgetOk(c, "fetches", "academy_daily_fetch_cap", 2000))) {
    return "budget_fetch";
  }
  const feeds: { url?: string }[] | string[] = src.feed_urls ?? [];
  let found = 0;
  let anySuccess = false;
  for (const f of feeds as any[]) {
    const url = typeof f === "string" ? f : f?.url;
    if (!url) continue;
    const headers: Record<string, string> = {};
    if (src.etag) headers["If-None-Match"] = src.etag;
    if (src.http_last_modified) {
      headers["If-Modified-Since"] = src.http_last_modified;
    }
    const r = await safeFetch(url, src.domain, headers);
    await incrUsage(c, "fetches", 1);
    if (!r) continue;
    if (r.status === 304) {
      anySuccess = true;
      continue;
    }
    if (r.status !== 200 || !r.text) continue;
    anySuccess = true;
    if (/<(rss|feed)[\s>]/i.test(r.text)) {
      const items = parseFeed(r.text).slice(0, 25);
      for (const it of items) {
        if (!isAllowedUrl(it.link, src.domain)) continue;
        const fp = await textFingerprint(it.title + " " + it.summary);
        const { error } = await c.from("academy_content_items").insert({
          source_id: src.id,
          canonical_url: it.link,
          url: it.link,
          title: it.title.slice(0, 300),
          published_at: it.publishedAt,
          excerpt: it.summary,
          text_fingerprint: fp,
          status: "discovered",
        });
        if (!error) found++;
        // unique ihlali = zaten var (tekrar tek adaya düşer) → sayma.
      }
      const et = r.headers.get("etag");
      const lm = r.headers.get("last-modified");
      await c.from("academy_sources").update({
        etag: et ?? src.etag,
        http_last_modified: lm ?? src.http_last_modified,
      }).eq("id", src.id);
    }
  }
  await c.from("academy_sources").update({
    last_attempt_at: new Date().toISOString(),
    ...(anySuccess
      ? {
        last_success_at: new Date().toISOString(),
        consecutive_failures: 0,
        last_error: null,
        status: src.status === "candidate" && found > 0
          ? "active"
          : src.status,
      }
      : {
        consecutive_failures: (src.consecutive_failures ?? 0) + 1,
        last_error: "fetch_failed_all_urls",
        status: (src.consecutive_failures ?? 0) + 1 >= 5
          ? "degraded"
          : src.status,
      }),
  }).eq("id", src.id);
  return anySuccess ? `scanned_found_${found}` : "scan_failed";
}

async function handleDraft(c: any, payload: any): Promise<string> {
  const { data: item } = await c.from("academy_content_items").select("*")
    .eq("id", payload.item_id).maybeSingle();
  if (!item) return "item_not_found";
  if (!["discovered", "read", "normalized", "eligible"].includes(item.status)) {
    return "item_" + item.status;
  }
  const { data: src } = await c.from("academy_sources").select("*")
    .eq("id", item.source_id).maybeSingle();
  if (!src) return "source_not_found";

  // Tam metin yoksa izinli makale sayfasını oku (RSS özet yeterli değilse).
  let fullText = item.full_text ?? "";
  if (fullText.length < 400) {
    const r = await safeFetch(item.url, src.domain);
    await incrUsage(c, "fetches", 1);
    if (r && r.status === 200 && r.text) {
      const page = extractPage(r.text, item.url);
      fullText = page.text;
      await c.from("academy_content_items").update({
        full_text: fullText.slice(0, 60000),
        status: "read",
        updated_at: new Date().toISOString(),
      }).eq("id", item.id);
    }
  }
  if (fullText.length < 300) {
    await c.from("academy_content_items").update({
      status: "rejected",
      status_reason: "insufficient_text",
    }).eq("id", item.id);
    return "rejected_insufficient_text";
  }

  // Bot ataması: kaynağın konularından, o botun kaynağı olan ilk bot.
  const botKey = payload.bot_key ?? item.assigned_bot_key ??
    (src.topics?.[0] as string | undefined);
  if (!botKey) return "no_bot";
  const { data: bot } = await c.from("academy_bot_profiles").select("*")
    .eq("bot_key", botKey).maybeSingle();
  const { data: style } = await c.from("academy_bot_settings")
    .select("style_prompt").eq("bot_key", botKey).maybeSingle();
  if (!bot || !bot.is_active) return "bot_disabled";

  const prompt = buildDraftPrompt({
    botName: botKey,
    style: style?.style_prompt ?? "",
    subtopics: bot.subtopics ?? [],
    sourceSlug: src.slug,
    sourceName: src.name,
    isCommercial: src.is_commercial,
    contentKindHint: item.content_kind,
    title: item.title,
    publishedAt: item.published_at,
    text: fullText,
  });
  const r = await deepseek(c, prompt.system, prompt.user, 1800);
  if (!r.ok) {
    if (r.reason === "no_key") return "dead_no_llm_key";
    return "llm_" + r.reason;
  }
  const v = validateDraftOutput(r.content, new Set([src.slug]), [src.domain]);
  if (!v.ok) {
    await c.from("academy_content_items").update({
      status: "failed",
      status_reason: "draft_" + v.reason,
    }).eq("id", item.id);
    return "invalid_output_" + v.reason;
  }
  const d = v.draft;
  const { error } = await c.from("academy_drafts").insert({
    content_item_id: item.id,
    bot_key: botKey,
    kind: d.kind,
    topic: d.topic || bot.topic,
    title: d.title,
    body: d.body,
    practical_notes: d.practical_notes,
    tags: d.tags,
    claims: d.claims,
    source_ids: [src.id],
    date_context: d.date_context,
    image_brief: d.image_brief,
    uncertainties: d.uncertainties,
    publishable: d.publishable,
    model: DEEPSEEK_MODEL,
    tokens_in: r.tokensIn,
    tokens_out: r.tokensOut,
    status: d.publishable ? "checked" : "rejected",
    status_reason: d.publishable ? null : "model_not_publishable",
    idempotency_key: `item:${item.id}:${botKey}`,
  });
  if (error && !String(error.message).includes("duplicate")) {
    return "draft_insert_failed";
  }
  await c.from("academy_content_items").update({
    status: "drafted",
    assigned_bot_key: botKey,
  }).eq("id", item.id);
  return d.publishable ? "drafted" : "drafted_not_publishable";
}

async function handlePublish(c: any, payload: any): Promise<string> {
  const { data, error } = await c.rpc("academy_publish_draft", {
    p_draft_id: payload.draft_id,
  });
  if (error) return "publish_rpc_error";
  const row = Array.isArray(data) ? data[0] : data;
  return String(row?.result ?? "unknown");
}

async function handleHumorPost(c: any, payload: any): Promise<string> {
  const prompt = buildHumorPrompt();
  const r = await deepseek(c, prompt.system, prompt.user, 500);
  if (!r.ok) return r.reason === "no_key" ? "dead_no_llm_key" : "llm_" + r.reason;
  const v = validateHumorOutput(r.content);
  if (!v.ok) return "invalid_output_" + v.reason;
  const idem = payload.idempotency_key ??
    `humor:${new Date().toISOString().slice(0, 10)}`;
  const { data: draft, error } = await c.from("academy_drafts").insert({
    bot_key: "mizah",
    kind: "humor",
    topic: "mizah",
    title: v.humor.title,
    body: v.humor.body,
    publishable: v.humor.publishable,
    model: DEEPSEEK_MODEL,
    tokens_in: r.tokensIn,
    tokens_out: r.tokensOut,
    status: v.humor.publishable ? "checked" : "rejected",
    idempotency_key: idem,
  }).select("id").maybeSingle();
  if (error) {
    return String(error.message).includes("duplicate")
      ? "duplicate_humor_today"
      : "draft_insert_failed";
  }
  if (!v.humor.publishable) return "humor_not_publishable";
  return await handlePublish(c, { draft_id: draft!.id });
}

async function handleMaintenance(c: any): Promise<string> {
  // Orkestrasyon: taranacak kaynaklar + taslak/yayın işleri kuyruklanır.
  const enabled = await cfgBool(c, "academy_enabled", false);
  if (!enabled) return "academy_disabled";
  const now = new Date();
  const slot = now.toISOString().slice(0, 13); // saatlik dedupe

  // 1) Vadesi gelen kaynaklar → scan_source.
  const { data: due } = await c.from("academy_sources")
    .select("id, slug, check_interval_minutes, last_attempt_at, status")
    .in("status", ["candidate", "active"]).limit(200);
  let scans = 0;
  for (const s of due ?? []) {
    const last = s.last_attempt_at ? Date.parse(s.last_attempt_at) : 0;
    if (now.getTime() - last < s.check_interval_minutes * 60000) continue;
    await c.rpc("academy_enqueue_job", {
      p_job_type: "scan_source",
      p_payload: { source_id: s.id },
      p_dedupe_key: `scan:${s.slug}:${slot}`,
    });
    scans++;
  }

  // 2) Uygun adaylar → draft (günlük hedefe göre).
  const target = await cfgInt(c, "academy_daily_post_target", 6);
  const { data: items } = await c.from("academy_content_items")
    .select("id").in("status", ["discovered", "read", "eligible"])
    .order("published_at", { ascending: false, nullsFirst: false })
    .limit(target * 2);
  for (const it of items ?? []) {
    await c.rpc("academy_enqueue_job", {
      p_job_type: "draft",
      p_payload: { item_id: it.id },
      p_dedupe_key: `draft:${it.id}`,
      p_max_attempts: 3,
    });
  }

  // 3) Yayına hazır taslaklar → publish.
  const { data: ready } = await c.from("academy_drafts").select("id")
    .in("status", ["checked", "media_ready", "scheduled"])
    .or(`scheduled_for.is.null,scheduled_for.lte.${now.toISOString()}`)
    .limit(target);
  for (const d of ready ?? []) {
    await c.rpc("academy_enqueue_job", {
      p_job_type: "publish",
      p_payload: { draft_id: d.id },
      p_dedupe_key: `publish:${d.id}`,
      p_max_attempts: 3,
    });
  }

  // 4) Günde bir mizah gönderisi.
  await c.rpc("academy_enqueue_job", {
    p_job_type: "humor_post",
    p_payload: {},
    p_dedupe_key: `humor:${now.toISOString().slice(0, 10)}`,
    p_max_attempts: 2,
  });
  return `orchestrated_scans_${scans}`;
}

// ── HTTP giriş noktası ───────────────────────────────────────────────
Deno.serve(async (req) => {
  if (req.method !== "POST") {
    return new Response(JSON.stringify({ error: "method" }), { status: 405 });
  }
  if (!WORKER_TOKEN) {
    return new Response(JSON.stringify({ error: "no_secret" }), {
      status: 503,
    });
  }
  const auth = req.headers.get("authorization") ?? "";
  if (auth !== `Bearer ${WORKER_TOKEN}`) {
    return new Response(JSON.stringify({ error: "unauthorized" }), {
      status: 401,
    });
  }
  if (!SUPABASE_URL || !SERVICE_KEY) {
    return new Response(JSON.stringify({ error: "no_backend" }), {
      status: 503,
    });
  }
  let body: any = {};
  try {
    body = await req.json();
  } catch (_) { /* boş gövde = process */ }
  const c = db();
  const workerId = `edge-${crypto.randomUUID().slice(0, 8)}`;
  const maxJobs = Math.min(Number(body.max_jobs ?? 5), 10);

  if (body.action === "tick") {
    const r = await handleMaintenance(c);
    return new Response(JSON.stringify({ ok: true, tick: r }));
  }

  const { data: jobs, error } = await c.rpc("academy_claim_jobs", {
    p_worker: workerId,
    p_limit: maxJobs,
    p_lease_seconds: 120,
  });
  if (error) {
    return new Response(JSON.stringify({ error: "claim_failed" }), {
      status: 500,
    });
  }
  const results: Record<string, string> = {};
  for (const job of jobs ?? []) {
    let outcome = "failed";
    let detail = "";
    try {
      switch (job.job_type) {
        case "scan_source":
          detail = await handleScanSource(c, job.payload);
          break;
        case "draft":
          detail = await handleDraft(c, job.payload);
          break;
        case "publish":
          detail = await handlePublish(c, job.payload);
          break;
        case "humor_post":
          detail = await handleHumorPost(c, job.payload);
          break;
        case "maintenance":
          detail = await handleMaintenance(c);
          break;
        default:
          detail = "unknown_job_type";
      }
      // dead_* → kalıcı engel (ör. LLM anahtarı yok): retry fırtınası yok.
      outcome = detail.startsWith("dead_")
        ? "dead"
        : (detail.startsWith("llm_") || detail === "scan_failed" ||
            detail === "publish_rpc_error")
        ? "failed"
        : "succeeded";
    } catch (e) {
      detail = "exception: " + String(e).slice(0, 300);
      outcome = "failed";
    }
    await c.rpc("academy_complete_job", {
      p_job_id: job.id,
      p_outcome: outcome,
      p_error: outcome === "succeeded" ? null : detail,
      p_retry_delay_seconds: 300,
      p_worker: workerId,
    });
    results[String(job.id)] = detail;
  }
  return new Response(
    JSON.stringify({ ok: true, processed: Object.keys(results).length,
      results }),
  );
});
