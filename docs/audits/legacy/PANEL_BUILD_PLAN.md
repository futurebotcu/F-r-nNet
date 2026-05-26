# PANEL_BUILD_PLAN

**Tarih:** 2026-05-13
**Faz:** V1.2 — Üç rol panelinin doldurulması (Ticari + Bireysel + Toptancı)
**Kapsam:** Sadece paneller + arkadaki Supabase kalıcılığı. Feed/Market/Jobs ana tab'larına dokunulmayacak.

> Önceki audit: [`PANEL_CURRENT_STRUCTURE_AUDIT.md`](PANEL_CURRENT_STRUCTURE_AUDIT.md). Bu plan ondaki "kritik eksikler" listesini hedefliyor.

---

## 1. Mevcut eksikler (audit özeti)

### Ticari
- Standalone **Hesaplama Makinesi** yok — hesap için Yeni Reçete sihirbazına girilmesi gerekiyor.
- Bayi tarafında **payment / return / adjustment / price / multi-note** local-only — uygulama restart'ında kaybolur (kritik prod blocker).
- `dealers.contact_name`, `dealers.working_type` Supabase'de **yok**; UI'da tutulan değer kaydedilmiyor.

### Bireysel
- "İş Arıyorum İlanı Ver", "Mesajlar" comingSoon snackbar.
- Usta profili, tecrübe, beceri yok.
- Tek gerçek modül: Reçetelerim + Profil.

### Toptancı
- "Ürün/Hizmet İlanı Ver" statik mock marketplace'e atıyor — gerçek yayın akışı yok.
- Müşteri/bayi yönetimi yok.
- Fiyat listesi, duyuru, gelen mesaj — hepsi comingSoon.

---

## 2. Eklenecek modüller

### Ticari panel
| Modül | Yeni mi? | Karar |
|---|---|---|
| Fırın Paneli | Var | Korunuyor. Hesaplama Makinesi yan butonu içeri eklenebilir; **şimdilik** üst panelde ayrı kart olarak duracak. |
| Bayi Paneli | Var (UI), eksik (persist) | **DealerDetail aksiyon zincirinin Supabase'e tam bağlanması** — kritik. |
| Hesaplama Makinesi | **YENİ** | `/calculator` standalone route. RecipeCalculator.calculateFromQuantities + "Reçete olarak kaydet" + share. |
| Reçetelerim | Var | Korunuyor. |
| İlanlarım | Yanıltıcı | `/jobs` zaten "tüm ilanlar". V1.2'de **kart adını "İş İlanları" yap** + ileride owner filtresi ekle. |
| Mesajlar | comingSoon | comingSoon kalsın (V2 messaging). |

**Bayi 4x4 grid'i yerine** mevcut DealerList + DealerDetail kullanışlı kalır. Brief'teki 16 aksiyonun çoğu zaten DealerDetail'de mevcut (Ürün Ver/İade/Ödeme/Düzeltme/Fiyat/Not/Paylaş). 4x4 landing page eklersek aynı şeyi 2 yerde sunmuş oluruz. **Karar: Mevcut list+detail mimarisi korunsun;** eksik Supabase persistence kapatılsın.

### Bireysel panel
| Modül | Yeni mi? | Karar |
|---|---|---|
| İş Arıyorum İlanı Ver | **YENİ** | `JobSeekPostFormScreen` + `JobSeekPostsListScreen` (kendi ilanları) |
| Ustalık Bilgilerim | **YENİ** | `WorkerProfileScreen` (profession_badge, experience_years, cities, skills, bio, salary, work_type, shift) |
| Tecrübe / Çalışma Geçmişi | **YENİ** | `WorkerExperienceListScreen` + form |
| Hesaplama Makinesi | **YENİ (paylaşımlı)** | Aynı `/calculator` |
| Reçetelerim | Var | Korunuyor. |
| Mesajlar | comingSoon | comingSoon kalsın. |
| Profilim | Var | Korunuyor. |

### Toptancı panel
| Modül | Yeni mi? | Karar |
|---|---|---|
| Ürün / Hizmet İlanı Ver | comingSoon-mock | V1.2 dışı (V1.3 product listing scope çok büyük). comingSoon olarak temiz mesaj. |
| Müşteri / Bayi Listesi | **YENİ (UI), altyapı paylaşılıyor** | `dealers` tablosu + `customer_type` sütunu → toptancı için `wholesale_customer`. UI: `WholesaleCustomerListScreen` (DealerListScreen'in toptancı-etiketli versiyonu). |
| Bayiye/Müşteriye Mal Ver | Var (altyapı) | DealerDeliveryFormScreen reuse. |
| Tahsilat Al | Var (altyapı, persist eksik) | Migration A çözüyor. |
| Fiyat Listesi | Var (altyapı, persist eksik) | Migration A çözüyor. |
| Duyuru Gönder | comingSoon | V1.2 dışı. |
| Rapor Paylaş | Mevcut DealerShare reuse | Toptancı için aynı UI etiketi "Müşteri/Bayi". |
| Firma Profilim | Var | Korunuyor. |
| Mesajlar | comingSoon | comingSoon kalsın. |

---

## 3. Kullanılacak tablolar

### Var olanlar (V1)
- `bakeries`, `bakery_products`, `production_entries`, `waste_entries`
- `dealers`, `dealer_deliveries`, `dealer_delivery_items`
- `recipe_calculations` (+ V1.1 metadata + V1.1 visibility)
- `profiles` + auth triggers

### Yeni eklenecekler

#### Migration A — `20260513_firinnet_dealer_v1_2_extensions.sql`
```sql
-- dealers'a yeni sütunlar
alter table public.dealers
  add column if not exists contact_name text,
  add column if not exists working_type text,
  add column if not exists customer_type text not null default 'bakery_dealer'
    check (customer_type in ('bakery_dealer','wholesale_customer'));

-- Transactions (payment/return/adjustment ve gelecekte delivery kopya)
create table public.dealer_transactions (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null references public.profiles(id) on delete cascade,
  dealer_id uuid not null references public.dealers(id) on delete cascade,
  type text not null check (type in ('delivery','payment','return','adjustment')),
  product_name text,
  quantity integer check (quantity is null or quantity >= 0),
  unit_price numeric(12,2) check (unit_price is null or unit_price >= 0),
  amount numeric(12,2) not null default 0,
  payment_method text check (payment_method is null or payment_method in ('cash','transfer','card','other')),
  note text,
  created_at timestamptz not null default now()
);

-- Prices (bayi+ürün+geçerlilik)
create table public.dealer_prices (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null references public.profiles(id) on delete cascade,
  dealer_id uuid not null references public.dealers(id) on delete cascade,
  product_name text not null,
  unit_price numeric(12,2) not null check (unit_price >= 0),
  valid_from date not null default current_date,
  note text,
  created_at timestamptz not null default now()
);

-- Notes (çoklu)
create table public.dealer_notes (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null references public.profiles(id) on delete cascade,
  dealer_id uuid not null references public.dealers(id) on delete cascade,
  note text not null,
  created_at timestamptz not null default now()
);

-- Indexler
create index idx_dealer_transactions_dealer_created on public.dealer_transactions(dealer_id, created_at desc);
create index idx_dealer_transactions_owner_created on public.dealer_transactions(owner_id, created_at desc);
create index idx_dealer_prices_dealer_product on public.dealer_prices(dealer_id, product_name, valid_from desc);
create index idx_dealer_notes_dealer_created on public.dealer_notes(dealer_id, created_at desc);
create index idx_dealers_customer_type on public.dealers(owner_id, customer_type);

-- RLS owner CRUD (üç tablonun da paterni aynı)
alter table public.dealer_transactions enable row level security;
alter table public.dealer_prices       enable row level security;
alter table public.dealer_notes        enable row level security;

create policy dealer_transactions_select_own on public.dealer_transactions for select to authenticated using (owner_id = auth.uid());
create policy dealer_transactions_insert_own on public.dealer_transactions for insert to authenticated with check (owner_id = auth.uid());
create policy dealer_transactions_update_own on public.dealer_transactions for update to authenticated using (owner_id = auth.uid()) with check (owner_id = auth.uid());
create policy dealer_transactions_delete_own on public.dealer_transactions for delete to authenticated using (owner_id = auth.uid());

-- (dealer_prices ve dealer_notes için aynı 4 policy)
```

#### Migration B — `20260513_firinnet_worker_and_jobseek.sql`
```sql
create table public.worker_profiles (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null unique references public.profiles(id) on delete cascade,
  profession_badge text,
  experience_years integer check (experience_years is null or experience_years >= 0),
  cities text[] not null default '{}',
  shift_preference text,           -- gunduz / gece / vardiyali / esnek
  salary_expectation numeric(12,2),
  work_type text,                  -- tam_zamanli / part_time / sezonluk
  skills text[] not null default '{}',
  bio text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.worker_experiences (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null references public.profiles(id) on delete cascade,
  title text not null,
  workplace text,
  city text,
  start_date date,
  end_date date,
  description text,
  created_at timestamptz not null default now()
);

create table public.job_seek_posts (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null references public.profiles(id) on delete cascade,
  title text not null,
  profession_badge text,
  city text,
  experience_years integer check (experience_years is null or experience_years >= 0),
  salary_expectation numeric(12,2),
  description text,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index idx_worker_experiences_owner on public.worker_experiences(owner_id, start_date desc nulls last);
create index idx_job_seek_posts_active on public.job_seek_posts(is_active, created_at desc) where is_active = true;

alter table public.worker_profiles  enable row level security;
alter table public.worker_experiences enable row level security;
alter table public.job_seek_posts    enable row level security;

-- worker_profiles owner CRUD + diğer authenticated read (profil sayfasında görünür)
create policy worker_profiles_select_own_or_pub on public.worker_profiles
  for select to authenticated
  using (owner_id = auth.uid() or true);   -- okuma serbest, edit owner-only
create policy worker_profiles_insert_own on public.worker_profiles
  for insert to authenticated with check (owner_id = auth.uid());
create policy worker_profiles_update_own on public.worker_profiles
  for update to authenticated using (owner_id = auth.uid()) with check (owner_id = auth.uid());
create policy worker_profiles_delete_own on public.worker_profiles
  for delete to authenticated using (owner_id = auth.uid());

-- worker_experiences aynı pattern (owner CRUD, read public)
-- job_seek_posts owner CRUD + authenticated active read
create policy job_seek_posts_select_active on public.job_seek_posts
  for select to authenticated using (is_active = true or owner_id = auth.uid());
create policy job_seek_posts_insert_own on public.job_seek_posts
  for insert to authenticated with check (owner_id = auth.uid());
create policy job_seek_posts_update_own on public.job_seek_posts
  for update to authenticated using (owner_id = auth.uid()) with check (owner_id = auth.uid());
create policy job_seek_posts_delete_own on public.job_seek_posts
  for delete to authenticated using (owner_id = auth.uid());
```

---

## 4. Toptancı için A vs B kararı

> Brief: *"Daha temiz ve karışmayacaksa B tercih edilebilir. Ama fazla karmaşıysa önce mevcut ortak transaction modelini kullan."*

**Karar: Seçenek A (reuse).** Gerekçeler:
- `dealers` ve `dealer_transactions` zaten owner-based RLS ile koşuyor; bir `customer_type` text sütunu ekleyince ticari/toptancı paneli aynı altyapıyı paylaşır.
- UI'da yalnız liste/etiket farkı: ticari panel "Bayiler", toptancı panel "Müşteriler/Bayiler".
- Ayrı `wholesale_*` tablo seti = bakım yükü iki kat, kod duplikasyonu.
- Toptancı ileride gerçekten ayrı bir veri modeli isterse (örn. bayi-toptancı ilişkisi farklı kolonlara muhtaç olursa) V2'de bölünebilir; tek `customer_type` sütunu geri dönüşü kolay.

**Sonuç:** Ortak `dealers` + `dealer_transactions` + `dealer_prices` + `dealer_notes`. `customer_type = 'bakery_dealer' | 'wholesale_customer'`.

---

## 5. Route planı

### Mevcut korunan
- `/feed`, `/groups`, `/market`, `/jobs`, `/panel` (shell tab'lar)
- `/panel/bakery`, `/panel/production`, `/panel/waste`, `/panel/end-of-day`, `/panel/report`
- `/dealers`, `/dealers/new`, `/dealers/:id{,/delivery,/return,/payment,/adjustment,/share}`
- `/recipes`, `/recipes/new`, `/recipes/:id{,/edit}`
- `/profile`, `/profile/create`
- `/panel/recipe` redirect → `/recipes`

### Yeni eklenecekler
- `/calculator` — Standalone hesap makinesi
- `/worker/profile` — Ustalık bilgilerim
- `/worker/experiences` — Tecrübe listesi
- `/worker/experiences/new` — Tecrübe ekle
- `/worker/job-seek` — İş Arıyorum ilanlarım (list + yeni)
- `/worker/job-seek/new` — Form
- `/worker/job-seek/:id/edit` — Düzenle
- `/wholesale/customers` — Toptancı müşteri listesi (alias)
- `/wholesale/customers/new` — Müşteri ekle (alias)
- `/wholesale/customers/:id` — Detay (alias)

Toptancı `/wholesale/customers` route'u aslında DealerListScreen'i `customer_type='wholesale_customer'` filtresi ile render eder; ayrı ekran sınıfı **gerekmiyor**, parametrik tek sınıf yeterli.

---

## 6. Test planı

### Korunacaklar (77)
Mevcut tüm testler değişmeden geçmeli.

### Yeni testler
| Test | İçerik |
|---|---|
| Calculator route exists + 316 calc | `flutter test` integration |
| RolePanelCards.commercial includes "Hesaplama Makinesi" | unit |
| RolePanelCards.individual includes worker + jobseek cards | unit |
| RolePanelCards.wholesaler includes customer route | unit |
| WorkerProfile JSON round-trip | unit |
| JobSeekPost JSON round-trip | unit |
| DealerTransaction Supabase mapping (test via builder) | unit |
| customer_type filter in dealers list (LocalDealerRepository) | unit |

---

## 7. PDF / Share kararı

- Mevcut `DealerShareBuilder` + `DealerPdfBuilder` ticari için kullanılmaya devam.
- Yeni flowlar için:
  - **Calculator paylaşımı:** RecipeShareTextBuilder reuse (kayıt yapmadan da çağrılabilir).
  - **JobSeekPost paylaşımı:** Yeni saf `JobSeekShareTextBuilder` (WhatsApp).
  - **Worker profile paylaşımı:** V1.2'de share text yeterli; PDF kalan iş.
- PDF V1.2 dışı (mevcut DealerPdfBuilder hariç).

---

## 8. Tasarım / kullanılabilirlik

- Renk/tema değişmiyor.
- Yeni ekranlar mevcut `PremiumCard` + `AppPrimaryButton` + `AppNumberField` + `PremiumScaffold` stilini kullanır.
- Empty state'ler standart: ikon + başlık + alt metin + CTA.
- Ticari panelde 6 kart (Fırın Paneli, Bayi Paneli, Hesaplama Makinesi, Reçetelerim, İlanlar, Mesajlar — Mesajlar comingSoon).

---

## 9. Uygulama sırası

1. **Migration A** uygula (dealer extensions).
2. **DealerRepository** abstract + Local + Supabase update (transactions/prices/notes/columns).
3. **Calculator screen** + route + ticari kart.
4. **Migration B** uygula (worker + jobseek).
5. **Worker profile** model + repo + UI.
6. **Job seek post** model + repo + UI + share text.
7. **Wholesale list/detail** reuse via DealerList with customer_type filter.
8. **RolePanelCards** update (3 rol).
9. **Tests** yaz, mevcut 77 + yeni testler.
10. **flutter analyze + flutter test** yeşil.
11. **Secret scan** + **git add + commit + push**.
12. **ROLE_PANELS_COMPLETION_REPORT.md** yaz.

---

## 10. Kabul kriterleri

V1.2 başarılı sayılır:
- [x] Bayi tarafında payment/return/adjustment/price/note Supabase'e kalıcı yazılıyor.
- [x] Standalone `/calculator` route çalışıyor, brief örneği 316 adet veriyor.
- [x] Bireysel kullanıcı worker profile + iş arıyorum ilanı oluşturabiliyor.
- [x] Toptancı `/wholesale/customers` üzerinden müşteri ekleyip teslimat/tahsilat kaydedebiliyor.
- [x] `flutter analyze` temiz, `flutter test` 77+ test yeşil.
- [x] Yeni migrationlar `supabase/migrations/` mirror'lanmış + remote'a uygulanmış.
- [x] RLS owner-only ihlal yok, anon erişim açılmadı.
- [x] git commit + push başarılı.

V1.2 başarılı sayılmaz / sonraki faza:
- [ ] Mesajlaşma altyapısı (3 rol comingSoon).
- [ ] Toptancı için ayrı "ürün yayını" akışı (`/market` statik mock).
- [ ] PDF builder yeni flowlar için (worker profile, job seek post, wholesale).
- [ ] JobsScreen'e owner filtresi (yine `JobsScreen` zaten tüm ilanlar).
- [ ] Topluluk ipuçları kartlarının Feed bağlamına taşınması.
- [ ] Reçete media upload.

---

Aşağıda implementasyon adım adım yürüyecek. Bu plan rapor sırasında ROLE_PANELS_COMPLETION_REPORT.md ile karşılaştırılacak; sapma olursa açıklanacak.
