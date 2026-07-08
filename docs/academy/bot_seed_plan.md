# FırınNet Akademi — Bot Kimlik Seed Planı (Path B)

Botlar **giriş yapamayan sistem `auth.users` + `profiles`** satırlarıdır (insan/
giriş hesabı DEĞİL). Migration bunları **SEED ETMEZ** (canlı auth/profiles yazımı
migration'da yapılmaz); kurulum ayrı, kontrollü **service_role/backoffice**
adımıdır. Bu doküman o adımı tanımlar. **PR A1 kapsamında UYGULANMAZ.**

## Neden migration'da seed yok?
- `auth.users` yazımı migration'da güvenli değil (GoTrue token kolon riski,
  geri-alınamaz kimlik oluşturma).
- Bot kimliği = insan-benzeri hesap; kontrollü/onaylı kurulmalı.

## 11 Akademi hesabı (bot_key → display_name / topic)
| bot_key | display_name | topic |
|---|---|---|
| akademi | FırınNet Akademi | akademi |
| haber | FırınNet Haber | haber |
| makine | FırınNet Makine | makine |
| un | FırınNet Un | un |
| hammadde | FırınNet Hammadde | hammadde |
| usta | FırınNet Usta | usta |
| tarif | FırınNet Tarif | tarif |
| maliyet | FırınNet Maliyet | maliyet |
| trend | FırınNet Trend | trend |
| hijyen | FırınNet Hijyen | hijyen |
| fuar_sektor | FırınNet Fuar & Sektör | fuar_sektor |

## Kurulum adımları (service_role, backoffice — canlı)

Her bot için:
1. **auth.users**: giriş-kapalı sistem hesabı. Admin API (`auth.admin.createUser`)
   ile `email_confirm: true`, parola YOK / kullanılmaz; ya da doğrudan SQL ile
   (tüm token kolonları `''`, `encrypted_password` boş). **Bu hesaplar giriş
   akışına sokulmaz** (login UI'ında görünmez; social/email login denenmez).
2. **profiles**: `id = <bot auth uid>`, `display_name = '<FırınNet ...>'`,
   `account_type = 'individual'` (mevcut değerlerden biri — yeni account_type
   yok), `is_bot = true`, opsiyonel `avatar_url`.
3. **academy_bot_profiles**: `profile_id = <bot uid>`, `bot_key`, `topic`,
   `bio`, `is_active = true`, `is_visible = true`, `posting_enabled = true`,
   `daily_post_limit = 1`.

Örnek (service_role SQL — CANLI, kontrollü çalıştırılır; repo'da otomatik DEĞİL):

```sql
-- 1) sistem auth user (parolasız / giriş-kapalı)
insert into auth.users (instance_id, id, aud, role, email, email_confirmed_at,
  raw_app_meta_data, raw_user_meta_data, created_at, updated_at,
  confirmation_token, recovery_token, email_change_token_new, email_change,
  email_change_token_current, phone_change, phone_change_token, reauthentication_token)
values ('00000000-0000-0000-0000-000000000000', gen_random_uuid(), 'authenticated',
  'authenticated', 'bot+akademi@firinnet.system', now(),
  '{"provider":"system","providers":["system"]}', '{"is_bot":true}', now(), now(),
  '','','','','','','','')
returning id;
-- 2) profiles (yukarıdaki id ile), is_bot=true
-- 3) academy_bot_profiles (aynı id, bot_key='akademi', topic='akademi', ...)
```

## Güvenlik notları
- Bot postu YALNIZ service_role yazar (sonraki PR'daki içerik motoru). Kullanıcı
  bot adına post atamaz — `feed_posts_insert_self` (`owner_id = auth.uid()`)
  garanti eder (A1 smoke ile doğrulandı).
- Bot hesapları login akışına dahil edilmez; parola set edilmez.
- `is_visible=false` bot public listede görünmez (RLS).
- Bot silinirse `on delete cascade` ile profiles/academy satırı + feed postları
  temizlenir (kalıcı feed politikasıyla çelişebilir → botları silme yerine
  `is_active=false` yapmak önerilir).

## Sıradaki PR'lar
- A2: feed kartı bot rozeti/etiket + bot profil sayfası (is_bot okuması).
- A3+: içerik kaynak/aday sistemi + Edge içerik motoru (bu seed'ler yerinde
  olunca posting başlar).
