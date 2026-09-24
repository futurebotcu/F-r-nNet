// FirinNet - RevenueCat webhook -> entitlements/payment event log.
// Applies only authenticated RevenueCat webhook events. Client never applies
// subscriptions directly; all writes go through service_role RPCs.

// deno-lint-ignore-file
import { createClient } from "jsr:@supabase/supabase-js@2";

const AUTH_TOKEN = Deno.env.get("REVENUECAT_WEBHOOK_AUTH_TOKEN") ?? "";
const SIGNING_SECRET =
  Deno.env.get("REVENUECAT_WEBHOOK_SIGNING_SECRET") ?? "";
const SUPABASE_URL = Deno.env.get("SUPABASE_URL") ?? "";
const SERVICE_KEY =
  Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ??
  Deno.env.get("EDGE_SERVICE_ROLE_KEY") ??
  "";

const ACTIVE_TYPES = new Set([
  "INITIAL_PURCHASE",
  "RENEWAL",
  "PRODUCT_CHANGE",
  "UNCANCELLATION",
  "NON_RENEWING_PURCHASE",
]);
const TERMINAL_STATUS: Record<string, string> = {
  EXPIRATION: "expired",
  REFUND: "refunded",
  // CANCELLATION means auto-renew disabled; access remains until expiration.
};

function timingSafeEqual(a: string, b: string): boolean {
  if (a.length !== b.length) return false;
  let r = 0;
  for (let i = 0; i < a.length; i++) r |= a.charCodeAt(i) ^ b.charCodeAt(i);
  return r === 0;
}

async function hmacHex(secret: string, body: string): Promise<string> {
  const key = await crypto.subtle.importKey(
    "raw",
    new TextEncoder().encode(secret),
    { name: "HMAC", hash: "SHA-256" },
    false,
    ["sign"],
  );
  const sig = await crypto.subtle.sign(
    "HMAC",
    key,
    new TextEncoder().encode(body),
  );
  return Array.from(new Uint8Array(sig))
    .map((b) => b.toString(16).padStart(2, "0"))
    .join("");
}

function parseSignature(header: string): { timestamp: string; v1: string } | null {
  const parts = header.split(",").map((p) => p.trim());
  const map = new Map<string, string>();
  for (const part of parts) {
    const idx = part.indexOf("=");
    if (idx > 0) map.set(part.slice(0, idx), part.slice(idx + 1));
  }
  const timestamp = map.get("t") ?? "";
  const v1 = map.get("v1") ?? "";
  return timestamp && v1 ? { timestamp, v1 } : null;
}

function uuidOrNull(value: unknown): string | null {
  const s = String(value ?? "");
  return /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i
      .test(s)
    ? s
    : null;
}

function numberOrNull(value: unknown): number | null {
  const n = Number(value ?? 0);
  return Number.isFinite(n) && n > 0 ? n : null;
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok");
  if (req.method !== "POST") {
    return new Response(JSON.stringify({ error: "method" }), { status: 405 });
  }

  const rawBody = await req.text();

  const auth = req.headers.get("authorization") ?? "";
  const secretPresent = AUTH_TOKEN.length > 0;
  if (secretPresent) {
    const expected = `Bearer ${AUTH_TOKEN}`;
    const alt = AUTH_TOKEN;
    if (!timingSafeEqual(auth, expected) && !timingSafeEqual(auth, alt)) {
      return new Response(JSON.stringify({ error: "unauthorized" }), {
        status: 401,
      });
    }
  }

  if (SIGNING_SECRET.length > 0) {
    const sigHeader =
      req.headers.get("x-revenuecat-webhook-signature") ??
      req.headers.get("x-revenuecat-signature") ??
      req.headers.get("x-signature") ??
      "";
    const parsed = parseSignature(sigHeader);
    const computed = parsed
      ? await hmacHex(SIGNING_SECRET, `${parsed.timestamp}.${rawBody}`)
      : await hmacHex(SIGNING_SECRET, rawBody);
    const expected = parsed?.v1 ?? sigHeader;
    if (!timingSafeEqual(expected.toLowerCase(), computed.toLowerCase())) {
      return new Response(JSON.stringify({ error: "bad_signature" }), {
        status: 401,
      });
    }
  }

  let payload: Record<string, unknown>;
  try {
    payload = JSON.parse(rawBody);
  } catch (_) {
    return new Response(JSON.stringify({ error: "bad_json" }), { status: 400 });
  }

  const event = (payload.event ?? {}) as Record<string, unknown>;
  const eventId = String(event.id ?? "");
  if (!eventId) {
    return new Response(JSON.stringify({ error: "no_event_id" }), {
      status: 400,
    });
  }

  if (!SUPABASE_URL || !SERVICE_KEY) {
    return new Response(JSON.stringify({ ok: true, note: "no_backend" }));
  }
  const db = createClient(SUPABASE_URL, SERVICE_KEY);

  const eventType = String(event.type ?? "");
  const productId = String(event.product_id ?? "");
  const appUserId = String(event.app_user_id ?? "");
  const appUserUuid = uuidOrNull(appUserId);
  const eventTimestampMs = numberOrNull(event.event_timestamp_ms);
  const expiresAtMs = numberOrNull(event.expiration_at_ms);
  const expiresAt = expiresAtMs ? new Date(expiresAtMs).toISOString() : null;
  const entitlementId = Array.isArray(event.entitlement_ids)
    ? (event.entitlement_ids as string[]).join(",")
    : null;
  const transactionId = (event.transaction_id as string) ?? null;
  const originalTransactionId =
    (event.original_transaction_id as string) ?? null;
  const environment = (event.environment as string) ?? null;
  const store = (event.store as string) ?? null;

  async function complete(status: string, error: string | null = null) {
    return await db.rpc("complete_store_payment_event", {
      p_provider_event_id: eventId,
      p_processing_status: status,
      p_processing_error: error,
    });
  }

  const { data: claimRows, error: claimErr } = await db.rpc(
    "claim_store_payment_event",
    {
      p_provider_event_id: eventId,
      p_event_type: eventType,
      p_app_user_id: appUserUuid,
      p_product_id: productId || null,
      p_entitlement_id: entitlementId,
      p_transaction_id: transactionId,
      p_original_transaction_id: originalTransactionId,
      p_environment: environment,
      p_store: store,
      p_event_timestamp_ms: eventTimestampMs,
      p_raw_payload: payload,
      p_can_process: secretPresent,
    },
  );
  if (claimErr) {
    return new Response(JSON.stringify({ error: "claim_failed" }), {
      status: 500,
    });
  }
  const claim = Array.isArray(claimRows) ? claimRows[0] : claimRows;
  if (!claim?.should_process) {
    return new Response(
      JSON.stringify({
        ok: true,
        duplicate: true,
        result: claim?.current_status ?? "already_handled",
      }),
    );
  }

  if (!secretPresent) {
    return new Response(JSON.stringify({ ok: true, note: "no_secret" }));
  }

  const { data: mapRows, error: mapErr } = await db.rpc("store_product_mapping", {
    p_product_id: productId,
  });
  if (mapErr) {
    await complete("failed", `mapping:${mapErr.message}`);
    return new Response(JSON.stringify({ error: "mapping_failed" }), {
      status: 500,
    });
  }
  const mapping = Array.isArray(mapRows) ? mapRows[0] : null;

  let status = "unknown";
  let result = "ignored";

  if (mapping?.kind === "subscription" && appUserUuid) {
    if (ACTIVE_TYPES.has(eventType)) status = "active";
    else if (TERMINAL_STATUS[eventType]) status = TERMINAL_STATUS[eventType];
    else if (eventType === "CANCELLATION") status = "active";
    else status = "unknown";

    if (status === "active" || TERMINAL_STATUS[eventType]) {
      const { data: applyRes, error: applyErr } = await db.rpc(
        "apply_store_subscription",
        {
          p_user_id: appUserUuid,
          p_product_id: productId,
          p_status: status,
          p_store: store,
          p_environment: environment,
          p_transaction_id: transactionId,
          p_original_transaction_id: originalTransactionId,
          p_expires_at: expiresAt,
          p_event_timestamp_ms: eventTimestampMs,
          p_event_id: null,
          p_raw: payload,
        },
      );
      if (applyErr || typeof applyRes !== "string") {
        const detail = applyErr?.message ?? "null_apply_result";
        await complete("failed", `apply:${detail}`);
        return new Response(JSON.stringify({ error: "apply_failed" }), {
          status: 500,
        });
      }
      result = applyRes;
    } else {
      result = "ignored_status";
    }
  } else if (mapping?.kind === "listing_fee") {
    result = "recorded_listing_fee_needs_confirm";
  } else {
    result = "ignored_unknown_product";
  }

  const finalStatus = result.startsWith("applied_") ? "applied" : result;
  const { error: completeErr } = await complete(finalStatus);
  if (completeErr) {
    return new Response(JSON.stringify({ error: "complete_failed" }), {
      status: 500,
    });
  }

  return new Response(JSON.stringify({ ok: true, result }));
});
