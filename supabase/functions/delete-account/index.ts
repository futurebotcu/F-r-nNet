// FırınNet — `delete-account` Edge Function
//
// Amaç (P0 / KVKK / Google Play account-deletion compliance):
//   Kullanıcı yalnız kendi `auth.users` satırını siler. `profiles.id`
//   `auth.users(id)` FK'sine `on delete cascade` ile bağlı; tüm bağlı
//   tablolar (`bakeries`, `recipe_calculations`, `dealers`, `feed_*`,
//   `social_groups`, `group_*`, `worker_*`, `job_seek_posts`, ...) profiles
//   üzerinden zincirleme silinir.
//
// Güvenlik:
//   - `service_role` anahtarı yalnız bu function ortamında bulunur; mobile
//     binary'ye ASLA verilmez.
//   - Function caller'ın Authorization Bearer JWT'sini doğrular ve
//     `auth.admin.deleteUser` çağrısını HER ZAMAN o JWT'nin sahibinin
//     `id`'siyle yapar — body veya query'den user_id KABUL ETMEZ.
//   - Body'de `confirm === true` zorunlu (yanlışlıkla tetiklemeyi önler;
//     gerçek UX guard 2-aşamalı dialog ile zaten sağlanır).
//   - Anahtarlar/JWT/user_id konsola yazılmaz. Hata yanıtları opaque
//     (`{ "error": "<code>" }`).
//
// Çağırma:
//   POST /functions/v1/delete-account
//   Headers:
//     Authorization: Bearer <user_jwt>
//     apikey: <anon_or_service> (Supabase functions.invoke default'u set eder)
//     Content-Type: application/json
//   Body:
//     { "confirm": true }
//
// Başarı: 200 { "ok": true }
// Hata: 4xx/5xx { "error": "<code>" } — generic kodlar.

// deno-lint-ignore-file
import { createClient } from 'jsr:@supabase/supabase-js@2';

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers':
    'authorization, x-client-info, apikey, content-type',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
};

function jsonResponse(payload: unknown, status: number): Response {
  return new Response(JSON.stringify(payload), {
    status,
    headers: { ...corsHeaders, 'Content-Type': 'application/json' },
  });
}

Deno.serve(async (req: Request) => {
  // CORS preflight
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }
  if (req.method !== 'POST') {
    return jsonResponse({ error: 'method_not_allowed' }, 405);
  }

  // 1) Authorization header
  const authHeader = req.headers.get('Authorization');
  if (!authHeader || !authHeader.startsWith('Bearer ')) {
    return jsonResponse({ error: 'unauthorized' }, 401);
  }

  // 2) Body — confirm = true zorunlu
  let body: Record<string, unknown> = {};
  try {
    body = await req.json();
  } catch (_e) {
    // boş body — confirm yok demektir.
  }
  if (body?.confirm !== true) {
    return jsonResponse({ error: 'confirm_required' }, 400);
  }

  // 3) Env
  const url = Deno.env.get('SUPABASE_URL');
  const anonKey = Deno.env.get('SUPABASE_ANON_KEY');
  const serviceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY');
  if (!url || !anonKey || !serviceKey) {
    return jsonResponse({ error: 'misconfigured' }, 500);
  }

  // 4) Caller JWT verify — anon key ile RLS-aktif client, Authorization
  //    header forward'lanır; auth.getUser() JWT'yi doğrular ve user'ı döner.
  const userClient = createClient(url, anonKey, {
    global: { headers: { Authorization: authHeader } },
    auth: { autoRefreshToken: false, persistSession: false },
  });

  const { data: userData, error: userErr } = await userClient.auth.getUser();
  if (userErr || !userData?.user) {
    return jsonResponse({ error: 'unauthorized' }, 401);
  }
  const callerId: string = userData.user.id;

  // 5) Admin client (server-side only) — `auth.admin.deleteUser` ile yalnız
  //    caller'ın kendi id'sini siler. Body/query'den user_id ALINMAZ.
  const adminClient = createClient(url, serviceKey, {
    auth: { autoRefreshToken: false, persistSession: false },
  });

  const { error: deleteErr } = await adminClient.auth.admin.deleteUser(callerId);
  if (deleteErr) {
    return jsonResponse({ error: 'delete_failed' }, 500);
  }

  return jsonResponse({ ok: true }, 200);
});
