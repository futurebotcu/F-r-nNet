// FırınNet — revenuecat-webhook Edge Function
//
// RevenueCat webhook → user_entitlements / listing ödeme senkronizasyonu.
// Resmi ödeme modeli: App Store IAP + Play Billing, orkestrasyon RevenueCat.
// Havale/EFT/İyzico/Stripe YOK.
//
// Güvenlik (fail-closed):
//   - Authorization header == REVENUECAT_WEBHOOK_AUTH_TOKEN zorunlu.
//     Secret set edilmişse ve eşleşmezse → 401. Secret YOKSA hiçbir ödeme
//     APPLY edilmez (yalnız event kaydı, processing_status=skipped_no_secret).
//   - REVENUECAT_WEBHOOK_SIGNING_SECRET set ise raw body üzerinden
//     HMAC-SHA256 doğrulanır (timing-safe). Eşleşmezse → 401.
//   - provider_event_id UNIQUE → duplicate event idempotent (200).
//   - Bilinmeyen event/product → kaydedilir + ignore (crash yok).
//   - Ödeme YALNIZ apply_store_subscription / mark_listing_fee_paid_from_store
//     (service_role) ile uygulanır. Client asla apply edemez.
//
// NOT: Listing fee (consumable) webhook'ta intent'e eşlenemez (korelasyon yok)
// → yalnız kaydedilir; asıl publish authenticated revenuecat-confirm-listing-
// payment (RevenueCat REST doğrulamalı) ile yapılır.

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
  // CANCELLATION = auto-renew off; erişim expiry'e kadar sürer → downgrade YOK.
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

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok");
  if (req.method !== "POST") {
    return new Response(JSON.stringify({ error: "method" }), { status: 405 });
  }

  const rawBody = await req.text();

  // 1) Authorization header doğrula (fail-closed).
  const auth = req.headers.get("authorization") ?? "";
  const secretPresent = AUTH_TOKEN.length > 0;
  if (secretPresent) {
    const expected = `Bearer ${AUTH_TOKEN}`;
    const alt = AUTH_TOKEN; // dashboard bazen "Bearer" olmadan set eder
    if (!timingSafeEqual(auth, expected) && !timingSafeEqual(auth, alt)) {
      return new Response(JSON.stringify({ error: "unauthorized" }), {
        status: 401,
      });
    }
  }

  // 2) HMAC imza doğrula (secret varsa).
  if (SIGNING_SECRET.length > 0) {
    const sigHeader =
      req.headers.get("x-revenuecat-signature") ??
      req.headers.get("x-signature") ??
      "";
    const computed = await hmacHex(SIGNING_SECRET, rawBody);
    if (!timingSafeEqual(sigHeader.toLowerCase(), computed.toLowerCase())) {
      return new Response(JSON.stringify({ error: "bad_signature" }), {
        status: 401,
      });
    }
  }

  // 3) Parse.
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
    // Altyapı hazır değil → sessiz 200 (fake apply yok).
    return new Response(JSON.stringify({ ok: true, note: "no_backend" }));
  }
  const db = createClient(SUPABASE_URL, SERVICE_KEY);

  const eventType = String(event.type ?? "");
  const productId = String(event.product_id ?? "");
  const appUserId = String(event.app_user_id ?? "");
  const expiresAtMs = event.expiration_at_ms as number | undefined;
  const expiresAt = expiresAtMs
    ? new Date(expiresAtMs).toISOString()
    : null;

  // 4) Event kaydı (idempotent — UNIQUE provider_event_id).
  const { error: insErr } = await db.from("store_payment_events").insert({
    provider_event_id: eventId,
    event_type: eventType,
    app_user_id: appUserId || null,
    product_id: productId || null,
    entitlement_id: Array.isArray(event.entitlement_ids)
      ? (event.entitlement_ids as string[]).join(",")
      : null,
    transaction_id: (event.transaction_id as string) ?? null,
    original_transaction_id:
      (event.original_transaction_id as string) ?? null,
    environment: (event.environment as string) ?? null,
    store: (event.store as string) ?? null,
    raw_payload: payload,
    processing_status: secretPresent ? "received" : "skipped_no_secret",
  });
  if (insErr) {
    // Duplicate (unique violation) → idempotent success.
    if (insErr.code === "23505") {
      return new Response(JSON.stringify({ ok: true, duplicate: true }));
    }
    return new Response(JSON.stringify({ error: "db" }), { status: 500 });
  }

  // Secret yoksa apply etme (fail-closed) — event kaydı yeterli.
  if (!secretPresent) {
    return new Response(JSON.stringify({ ok: true, note: "no_secret" }));
  }

  // 5) Product mapping.
  const { data: mapRows } = await db.rpc("store_product_mapping", {
    p_product_id: productId,
  });
  const mapping = Array.isArray(mapRows) ? mapRows[0] : null;

  let status = "unknown";
  let result = "ignored";

  if (mapping?.kind === "subscription" && appUserId) {
    if (ACTIVE_TYPES.has(eventType)) status = "active";
    else if (TERMINAL_STATUS[eventType]) status = TERMINAL_STATUS[eventType];
    else if (eventType === "CANCELLATION") status = "active";
    else status = "unknown";

    if (status === "active" || TERMINAL_STATUS[eventType]) {
      const { data: applyRes } = await db.rpc("apply_store_subscription", {
        p_user_id: appUserId,
        p_product_id: productId,
        p_status: status,
        p_store: (event.store as string) ?? null,
        p_environment: (event.environment as string) ?? null,
        p_transaction_id: (event.transaction_id as string) ?? null,
        p_original_transaction_id:
          (event.original_transaction_id as string) ?? null,
        p_expires_at: expiresAt,
        p_event_id: null,
        p_raw: payload,
      });
      result = String(applyRes ?? "applied");
    } else {
      result = "ignored_status";
    }
  } else if (mapping?.kind === "listing_fee") {
    // Consumable → intent korelasyonu yok; yalnız kaydedilir.
    result = "recorded_listing_fee_needs_confirm";
  } else {
    result = "ignored_unknown_product";
  }

  await db
    .from("store_payment_events")
    .update({ processing_status: result, processed_at: new Date().toISOString() })
    .eq("provider_event_id", eventId);

  return new Response(JSON.stringify({ ok: true, result }));
});
