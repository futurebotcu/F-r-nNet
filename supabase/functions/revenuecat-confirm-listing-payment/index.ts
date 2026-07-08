// FırınNet — revenuecat-confirm-listing-payment Edge Function
//
// Ücretli ilan (50 TL, consumable) satın alımını GÜVENLİ doğrulayıp ilanı
// public yapar. Client transaction_id'ye GÜVENİLMEZ — backend RevenueCat REST
// üzerinden non-subscription purchase'ı doğrular.
//
// Akış: app create_listing_payment_intent → firinnet_listing_fee_50 purchase →
// bu endpoint (intent_id) → REST doğrulama → mark_listing_fee_paid_from_store
// (service_role) → ilan public. Webhook sonradan gelirse idempotent geçer.
//
// Güvenlik:
//   - Authorization Bearer JWT → auth.uid; intent owner == uid şart.
//   - REST key yoksa APPLY YOK (fake/self-pay yok) → verification_unavailable.
//   - mark yalnız service_role; idempotent (intent paid ise tekrar publish yok).

// deno-lint-ignore-file
import { createClient } from "jsr:@supabase/supabase-js@2";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL") ?? "";
const SERVICE_KEY =
  Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ??
  Deno.env.get("EDGE_SERVICE_ROLE_KEY") ??
  "";
const REST_KEY = Deno.env.get("REVENUECAT_REST_API_KEY") ?? "";
const LISTING_PRODUCT = "firinnet_listing_fee_50";

const cors = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: cors });

  const authHeader = req.headers.get("authorization") ?? "";
  if (!authHeader.startsWith("Bearer ") || !SUPABASE_URL || !SERVICE_KEY) {
    return new Response(JSON.stringify({ error: "unauthorized" }), {
      status: 401,
      headers: cors,
    });
  }

  let body: Record<string, unknown>;
  try {
    body = await req.json();
  } catch (_) {
    return new Response(JSON.stringify({ error: "bad_json" }), {
      status: 400,
      headers: cors,
    });
  }
  const intentId = String(body.intent_id ?? "");
  if (!intentId) {
    return new Response(JSON.stringify({ error: "no_intent" }), {
      status: 400,
      headers: cors,
    });
  }

  const userClient = createClient(SUPABASE_URL, SERVICE_KEY, {
    global: { headers: { Authorization: authHeader } },
  });
  const { data: userData } = await userClient.auth.getUser();
  const uid = userData?.user?.id;
  if (!uid) {
    return new Response(JSON.stringify({ error: "unauthorized" }), {
      status: 401,
      headers: cors,
    });
  }

  const db = createClient(SUPABASE_URL, SERVICE_KEY);

  // Intent'i yükle + owner doğrula.
  const { data: intent } = await db
    .from("listing_payment_intents")
    .select("id, owner_id, status")
    .eq("id", intentId)
    .maybeSingle();
  if (!intent || intent.owner_id !== uid) {
    return new Response(JSON.stringify({ error: "not_owner" }), {
      status: 403,
      headers: cors,
    });
  }
  if (intent.status === "paid") {
    return new Response(JSON.stringify({ ok: true, already_paid: true }), {
      headers: cors,
    });
  }

  // REST key yoksa doğrulanamaz → APPLY YOK (fake yok).
  if (!REST_KEY) {
    return new Response(
      JSON.stringify({ ok: false, note: "verification_unavailable" }),
      { headers: cors },
    );
  }

  // RevenueCat non-subscription purchase doğrula.
  let txId = "";
  try {
    const resp = await fetch(
      `https://api.revenuecat.com/v1/subscribers/${encodeURIComponent(uid)}`,
      { headers: { Authorization: `Bearer ${REST_KEY}` } },
    );
    if (resp.ok) {
      const j = await resp.json();
      const nonSubs = (j.subscriber?.non_subscriptions ?? {}) as Record<
        string,
        Array<Record<string, unknown>>
      >;
      const purchases = nonSubs[LISTING_PRODUCT] ?? [];
      if (purchases.length > 0) {
        const last = purchases[purchases.length - 1];
        txId = String(last.id ?? last.store_transaction_id ?? "verified");
      }
    }
  } catch (_) {
    return new Response(
      JSON.stringify({ ok: false, error: "revenuecat_unreachable" }),
      { status: 502, headers: cors },
    );
  }

  if (!txId) {
    return new Response(
      JSON.stringify({ ok: false, note: "purchase_not_found" }),
      { headers: cors },
    );
  }

  const { data: paidRes } = await db.rpc("mark_listing_fee_paid_from_store", {
    p_intent_id: intentId,
    p_transaction_id: txId,
    p_event_id: null,
  });

  return new Response(JSON.stringify({ ok: paidRes === true }), {
    headers: cors,
  });
});
