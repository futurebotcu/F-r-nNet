// Anlaşmalı İş Yeri başvurusu → destek e-postası (best-effort).
//
// Sözleşme:
//   * auth ZORUNLU (verify_jwt + token'dan kullanıcı çözülür).
//   * Body: { application_id } — yalnız ÇAĞIRANIN KENDİ başvurusu
//     mail'lenir (requester_id doğrulanır; enumeration yüzeyi yok).
//   * Mail provider (RESEND_API_KEY) veya hedef adres
//     (PARTNER_APPLICATION_EMAIL / SUPPORT_EMAIL) yoksa 200 +
//     "email_not_configured" döner — başvuru DB'de kalır, client kullanıcıya
//     yine başarı gösterir. Mail hatası HİÇBİR durumda başvuruyu bozmaz.

import { createClient } from "npm:@supabase/supabase-js@2";

function json(body: Record<string, unknown>, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "Content-Type": "application/json" },
  });
}

Deno.serve(async (req) => {
  try {
    const token = (req.headers.get("Authorization") ?? "").replace(
      "Bearer ",
      "",
    );
    if (!token) return json({ error: "auth required" }, 401);

    const body = await req.json().catch(() => ({}));
    const applicationId = body?.application_id;
    if (typeof applicationId !== "string" || applicationId.length === 0) {
      return json({ error: "application_id required" }, 400);
    }

    const supabase = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
    );
    const { data: userData, error: userErr } = await supabase.auth.getUser(
      token,
    );
    const uid = userData?.user?.id;
    if (userErr || !uid) return json({ error: "auth required" }, 401);

    const { data: app } = await supabase
      .from("partner_business_applications")
      .select(
        "id, requester_id, business_name, contact_name, phone, email, city, district, category, message, created_at",
      )
      .eq("id", applicationId)
      .maybeSingle();
    if (!app || app.requester_id !== uid) {
      return json({ error: "not found" }, 404);
    }

    const to = Deno.env.get("PARTNER_APPLICATION_EMAIL") ??
      Deno.env.get("SUPPORT_EMAIL");
    const resendKey = Deno.env.get("RESEND_API_KEY");
    if (!to || !resendKey) {
      return json({ status: "email_not_configured" });
    }

    const lines = [
      `İşletme adı: ${app.business_name}`,
      `Yetkili adı: ${app.contact_name}`,
      `Telefon: ${app.phone}`,
      `E-posta: ${app.email ?? "-"}`,
      `Şehir / İlçe: ${app.city} / ${app.district}`,
      `Kategori: ${app.category}`,
      `Mesaj: ${app.message ?? "-"}`,
      `Kullanıcı ID: ${app.requester_id}`,
      `Tarih: ${app.created_at}`,
    ];
    const res = await fetch("https://api.resend.com/emails", {
      method: "POST",
      headers: {
        Authorization: `Bearer ${resendKey}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        from: Deno.env.get("PARTNER_APPLICATION_FROM") ??
          "FirinNet <onboarding@resend.dev>",
        to: [to],
        subject: "FırınNet Anlaşmalı İş Yeri Başvurusu",
        text: lines.join("\n"),
      }),
    });
    if (!res.ok) return json({ status: "email_failed" });
    return json({ status: "sent" });
  } catch (_) {
    // Beklenmeyen hata da başvuru akışını KIRMAZ.
    return json({ status: "email_failed" });
  }
});
