// FırınNet — revenuecat-sync-my-entitlements Edge Function
//
// Kullanıcı purchase/restore sonrası beklemeden backend'i RevenueCat ile
// senkronlar. Yalnız KENDİ uid'sini sync eder (JWT'den; body'den uid ALINMAZ).
//
// Güvenlik:
//   - Authorization Bearer JWT doğrulanır → auth.uid.
//   - RevenueCat REST çağrısı server secret (REVENUECAT_REST_API_KEY) ile;
//     client REST key'i asla görmez.
//   - Entitlement YALNIZ apply_store_subscription (service_role) ile güncellenir.
//   - REST key yoksa → değişiklik yapılmaz (fake yok); mevcut plan döner.

// deno-lint-ignore-file
import { createClient } from "jsr:@supabase/supabase-js@2";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL") ?? "";
const SERVICE_KEY =
  Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ??
  Deno.env.get("EDGE_SERVICE_ROLE_KEY") ??
  "";
const REST_KEY = Deno.env.get("REVENUECAT_REST_API_KEY") ?? "";

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

  // Caller JWT → uid.
  const userClient = createClient(SUPABASE_URL, SERVICE_KEY, {
    global: { headers: { Authorization: authHeader } },
  });
  const { data: userData, error: userErr } = await userClient.auth.getUser();
  const uid = userData?.user?.id;
  if (userErr || !uid) {
    return new Response(JSON.stringify({ error: "unauthorized" }), {
      status: 401,
      headers: cors,
    });
  }

  const db = createClient(SUPABASE_URL, SERVICE_KEY);

  // REST key yoksa: fake yok — mevcut durumu döndür.
  if (!REST_KEY) {
    return new Response(
      JSON.stringify({ ok: true, synced: false, note: "no_rest_key" }),
      { headers: cors },
    );
  }

  // RevenueCat subscriber (appUserID = uid).
  let subscriber: Record<string, unknown> = {};
  try {
    const resp = await fetch(
      `https://api.revenuecat.com/v1/subscribers/${encodeURIComponent(uid)}`,
      { headers: { Authorization: `Bearer ${REST_KEY}` } },
    );
    if (resp.ok) {
      const j = await resp.json();
      subscriber = (j.subscriber ?? {}) as Record<string, unknown>;
    }
  } catch (_) {
    return new Response(
      JSON.stringify({ ok: false, error: "revenuecat_unreachable" }),
      { status: 502, headers: cors },
    );
  }

  const subs = (subscriber.subscriptions ?? {}) as Record<
    string,
    Record<string, unknown>
  >;
  const now = Date.now();
  let appliedPlan = "free";
  const entries = Object.entries(subs).map(([productId, info]) => {
    const expires = info.expires_date
      ? Date.parse(String(info.expires_date))
      : 0;
    return { productId, info, expires, active: expires > now };
  });
  const activeEntries = entries
    .filter((e) => e.active)
    .sort((a, b) => b.expires - a.expires);
  const entriesToApply = activeEntries.length > 0
    ? [activeEntries[0]]
    : entries.sort((a, b) => b.expires - a.expires);

  for (const { productId, info, expires, active } of entriesToApply) {
    const status = active ? "active" : "expired";
    const { data: applyRes } = await db.rpc("apply_store_subscription", {
      p_user_id: uid,
      p_product_id: productId,
      p_status: status,
      p_store: (info.store as string) ?? null,
      p_environment: (info.is_sandbox ? "sandbox" : "production"),
      p_transaction_id: null,
      p_original_transaction_id: null,
      p_expires_at: expires ? new Date(expires).toISOString() : null,
      p_event_id: null,
      p_raw: info,
    });
    if (active && typeof applyRes === "string" &&
        applyRes.startsWith("applied_active_")) {
      appliedPlan = applyRes.replace("applied_active_", "");
    }
  }

  return new Response(
    JSON.stringify({ ok: true, synced: true, plan: appliedPlan }),
    { headers: cors },
  );
});
