// FırınNet — push-dispatch Edge Function (PR-2, v8: canlı ile senkron)
//
// notifications INSERT → Database Webhook → bu fonksiyon → alıcının aktif FCM
// token'larına FCM HTTP v1 ile uygulama-dışı push. In-app notification merkezi
// değişmez.
//
// Güvenlik / kurallar:
// - Caller-auth (FN-AUDIT-001): PUSH_DISPATCH_KEY (veya PUSH_DISPATCH_WEBHOOK_SECRET)
//   secret'ı `Authorization: Bearer <secret>` ile doğrulanır. Secret yoksa veya
//   header eşleşmezse fail-closed (401, push yok). Database Webhook'un Authorization
//   header'ı bu secret ile AYNI olmalı (deploy sonrası manuel set; bkz. PR notu).
// - FIREBASE_SERVICE_ACCOUNT_JSON Supabase secret'ından (repo'ya ASLA yazılmaz).
//   Secret yoksa GRACEFUL no-op döner (in-app akışı bozulmaz).
// - DB erişimi service-role ile: SUPABASE_SERVICE_ROLE_KEY (yeni sb_secret
//   formatı) tercih edilir, yoksa EDGE_SERVICE_ROLE_KEY (legacy JWT) fallback.
//   service_role bu tablolarda DML grant'ına sahip olmalı (bkz.
//   grant_service_role_push_tables migration).
// - Payload minimal: title + body + data{route,type,entity_id,notification_id}.
// - Duplicate guard: notification_push_deliveries (notification_id, token_id).
// - Geçersiz token (UNREGISTERED/404/INVALID_ARGUMENT) → is_active=false.
//
// NOT: supabase-js @2 (latest) — yeni sb_secret API key formatı uyumu için.

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

interface ServiceAccount {
  client_email: string;
  private_key: string;
  project_id: string;
}

function pemToArrayBuffer(pem: string): ArrayBuffer {
  const b64 = pem
    .replace(/-----BEGIN PRIVATE KEY-----/, "")
    .replace(/-----END PRIVATE KEY-----/, "")
    .replace(/\s+/g, "");
  const bin = atob(b64);
  const buf = new Uint8Array(bin.length);
  for (let i = 0; i < bin.length; i++) buf[i] = bin.charCodeAt(i);
  return buf.buffer;
}

function b64url(data: ArrayBuffer | Uint8Array | string): string {
  let bytes: Uint8Array;
  if (typeof data === "string") bytes = new TextEncoder().encode(data);
  else if (data instanceof Uint8Array) bytes = data;
  else bytes = new Uint8Array(data);
  let bin = "";
  for (let i = 0; i < bytes.length; i++) bin += String.fromCharCode(bytes[i]);
  return btoa(bin).replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/, "");
}

// Service account → Google OAuth2 access token (FCM scope).
async function getAccessToken(sa: ServiceAccount): Promise<string> {
  const now = Math.floor(Date.now() / 1000);
  const unsigned =
    `${b64url(JSON.stringify({ alg: "RS256", typ: "JWT" }))}.${
      b64url(JSON.stringify({
        iss: sa.client_email,
        scope: "https://www.googleapis.com/auth/firebase.messaging",
        aud: "https://oauth2.googleapis.com/token",
        iat: now,
        exp: now + 3600,
      }))
    }`;
  const key = await crypto.subtle.importKey(
    "pkcs8",
    pemToArrayBuffer(sa.private_key),
    { name: "RSASSA-PKCS1-v1_5", hash: "SHA-256" },
    false,
    ["sign"],
  );
  const sig = await crypto.subtle.sign(
    "RSASSA-PKCS1-v1_5",
    key,
    new TextEncoder().encode(unsigned),
  );
  const jwt = `${unsigned}.${b64url(sig)}`;
  const res = await fetch("https://oauth2.googleapis.com/token", {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: new URLSearchParams({
      grant_type: "urn:ietf:params:oauth:grant-type:jwt-bearer",
      assertion: jwt,
    }),
  });
  if (!res.ok) {
    throw new Error(`oauth token failed: ${res.status} ${await res.text()}`);
  }
  return (await res.json()).access_token as string;
}

Deno.serve(async (req: Request) => {
  try {
    // Caller doğrulaması (FN-AUDIT-001): Database Webhook / dispatch trigger
    // paylaşılan secret'ı taşımalı. Gateway verify_jwt'ye EK katman: anon-key'i
    // olan biri push tetikleyemesin. Secret yoksa VEYA header eşleşmiyorsa
    // fail-closed (401, push gönderme). Secret değeri ASLA loglanmaz.
    const dispatchSecret = Deno.env.get("PUSH_DISPATCH_KEY") ??
      Deno.env.get("PUSH_DISPATCH_WEBHOOK_SECRET");
    const authHeader = req.headers.get("Authorization") ?? "";
    if (!dispatchSecret || authHeader !== `Bearer ${dispatchSecret}`) {
      return new Response(
        JSON.stringify({ ok: false, reason: "unauthorized" }),
        { status: 401, headers: { "Content-Type": "application/json" } },
      );
    }

    const saRaw = Deno.env.get("FIREBASE_SERVICE_ACCOUNT_JSON") ??
      Deno.env.get("FCM_SERVICE_ACCOUNT_JSON");
    const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
    const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ??
      Deno.env.get("EDGE_SERVICE_ROLE_KEY") ?? "";

    const payload = await req.json().catch(() => ({}));
    const notificationId: string | undefined = payload?.record?.id ??
      payload?.notification_id ?? payload?.id;
    if (!notificationId) {
      return new Response(
        JSON.stringify({ ok: false, reason: "no notification_id" }),
        { status: 400, headers: { "Content-Type": "application/json" } },
      );
    }
    if (!saRaw) {
      return new Response(
        JSON.stringify({ ok: true, skipped: "no_credential", notificationId }),
        { status: 200, headers: { "Content-Type": "application/json" } },
      );
    }

    const sa: ServiceAccount = JSON.parse(saRaw);
    const sb = createClient(supabaseUrl, serviceKey);

    const { data: notif, error: nErr } = await sb
      .from("notifications")
      .select("id, recipient_id, type, title, body, entity_id, route")
      .eq("id", notificationId)
      .single();
    if (nErr || !notif) {
      return new Response(
        JSON.stringify({
          ok: false,
          reason: "notification not found",
          detail: nErr?.message ?? null,
        }),
        { status: 404, headers: { "Content-Type": "application/json" } },
      );
    }

    const { data: tokens } = await sb
      .from("user_push_tokens")
      .select("id, token")
      .eq("user_id", notif.recipient_id)
      .eq("is_active", true);
    if (!tokens || tokens.length === 0) {
      return new Response(
        JSON.stringify({ ok: true, sent: 0, reason: "no active tokens" }),
        { status: 200, headers: { "Content-Type": "application/json" } },
      );
    }

    const accessToken = await getAccessToken(sa);
    const fcmUrl =
      `https://fcm.googleapis.com/v1/projects/${sa.project_id}/messages:send`;

    let sent = 0, skipped = 0, deactivated = 0;
    for (const t of tokens) {
      // Duplicate guard: bu bildirim bu token'a daha önce işlendiyse atla.
      const { error: dupErr } = await sb
        .from("notification_push_deliveries")
        .insert({
          notification_id: notif.id,
          user_id: notif.recipient_id,
          token_id: t.id,
          status: "pending",
        });
      if (dupErr) {
        skipped++;
        continue;
      }

      const message = {
        message: {
          token: t.token,
          notification: {
            title: notif.title ?? "FırınNet",
            body: notif.body ?? "",
          },
          data: {
            route: notif.route ?? "",
            type: notif.type ?? "",
            entity_id: notif.entity_id ?? "",
            notification_id: notif.id,
          },
          android: { priority: "HIGH" },
        },
      };
      const fcmRes = await fetch(fcmUrl, {
        method: "POST",
        headers: {
          "Authorization": `Bearer ${accessToken}`,
          "Content-Type": "application/json",
        },
        body: JSON.stringify(message),
      });

      if (fcmRes.ok) {
        sent++;
        await sb
          .from("notification_push_deliveries")
          .update({ status: "sent", sent_at: new Date().toISOString() })
          .eq("notification_id", notif.id)
          .eq("token_id", t.id);
      } else {
        const errText = await fcmRes.text();
        if (
          fcmRes.status === 404 ||
          errText.includes("UNREGISTERED") ||
          errText.includes("INVALID_ARGUMENT")
        ) {
          await sb
            .from("user_push_tokens")
            .update({ is_active: false })
            .eq("id", t.id);
          deactivated++;
        }
        await sb
          .from("notification_push_deliveries")
          .update({
            status: "error",
            error: `${fcmRes.status}: ${errText}`.slice(0, 500),
          })
          .eq("notification_id", notif.id)
          .eq("token_id", t.id);
      }
    }

    console.log(
      `[push-dispatch] notif=${notif.id} sent=${sent} skipped=${skipped} deactivated=${deactivated}`,
    );
    return new Response(
      JSON.stringify({ ok: true, sent, skipped, deactivated }),
      { status: 200, headers: { "Content-Type": "application/json" } },
    );
  } catch (e) {
    console.error("[push-dispatch] error:", e);
    return new Response(JSON.stringify({ ok: false, error: String(e) }), {
      status: 500,
      headers: { "Content-Type": "application/json" },
    });
  }
});
