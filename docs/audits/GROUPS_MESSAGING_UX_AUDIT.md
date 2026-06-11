# FırınNet Groups & Messaging UX/UI Audit

> Tarih: 2026-06-10 · Branch: `main` · Kapsam: Gruplar + Mesajlaşma deneyimi
> Tür: **AUDIT** (saf denetim). Bu sprintte kod davranışı değiştirilmedi; yalnızca bu doküman eklendi.
> Hedef seviye: Facebook/Messenger'a yaklaşan modern, güven veren, canlı sosyal deneyim.

İncelenen başlıca dosyalar:

- **Gruplar:** `lib/features/social_groups/screens/groups_list_screen.dart`, `group_detail_screen.dart`, `group_create_screen.dart`, `widgets/group_card.dart`, `providers/social_group_providers.dart`, `repositories/*`
- **Mesajlaşma (canlı/generic):** `lib/features/messages/screens/messages_list_screen.dart`, `lib/features/messaging/screens/chat_screen.dart`, `messaging/providers/messaging_providers.dart`, `messaging/repositories/*`
- **Mesajlaşma (legacy/job):** `lib/features/messages/screens/job_conversation_screen.dart`, `messages/repositories/*`
- **Ortak:** `lib/app/router/app_router.dart`, `lib/core/widgets/premium/premium_bottom_nav.dart`, `lib/features/auth/services/auth_required_guard.dart`, `lib/core/constants/app_strings.dart`

---

## Genel Verdict

**Gruplar deneyimi: B / B+.** Beklenenden iyi. Grup kartları gerçekten kaliteli (kategori gradient şeridi, kategori ikonu, üye sayısı + doluluk progress bar, şehir, "Katılım onaylı"/"Üye" mini rozetler, durum-bazlı CTA). Üyelik durumları (`Katıl` / `Sohbete katıl` / `Katılma isteği gönder` / `İstek gönderildi` / `Tekrar istek gönder` / `Dolu` / `Aç`) görsel olarak net. Arama + kategori filtresi + "üye olduğum gruplar" carousel'i var. Guest guard her yazma yolunda doğru. **Asıl eksik: grup *detayı* bir "topluluk alanı" gibi değil, sade bir sohbet ekranı gibi duruyor** — açıklama/kural/üye önizleme/aktivite hissi yok. Ve bir **gerçek bug** var: grup mesajlarının yazarı her zaman "Misafir" görünüyor.

**Mesajlaşma deneyimi: C+ / B-.** İskelet sağlam (Supabase + realtime + okundu RPC + unread sayacı + guest guard), konuşma listesi düzgün. Ama **canlı sohbet ekranı (`ChatScreen`) flutter_chat_ui'yi markasız varsayılan temayla** kullanıyor; ironik biçimde *legacy* job ekranının marka-uyumlu, daha güzel bubble'ları + boş state'i + loading'li gönder butonu var. **Mesaj gönderiminde hata olursa mesaj kaybolabiliyor** (sadece geçici snackbar, retry yok). **Global okunmamış badge hiçbir yerde yok** (alt nav badge desteklemiyor). İki paralel mesajlaşma sistemi (generic + legacy) dev tarafında karışıklık riski taşıyor.

**Tek cümlede:** Gruplar "yaşayan topluluk" hissine yakın ama detay ekranı zayıf; mesajlaşma "güvenilir modern chat" hissinden bir adım uzakta ve en büyük kazanç **zaten elimizde olan flutter_chat_ui paketini markaya göre temalandırmak + hata/teslim state'lerini görünür kılmak**. Yeni dependency'e gerek yok.

---

## Groups Experience

Gruplar ana ekranı (`groups_list_screen.dart`) ilk bakışta ne olduğunu iyi anlatıyor: `FirinNetHeader` "Sektör Grupları" + "Sektör konuşmaları, bölgesel ağlar" alt başlığı, bildirim zili (+ bekleyen istek badge'i), grup oluştur (+) aksiyonu. Altında arama kutusu, yatay kategori chip'leri, "Üyesi olduğum gruplar" carousel'i ve "Tüm gruplar" listesi.

`GroupCard` widget'ı kaliteli: kategori gradient kapak şeridi + kategori ikonu, grup adı, açıklama (2 satır), üye satırı (`{n}/{max} üye` veya `{n} üye · sınırsız`) + doluluk için `LinearProgressIndicator`, şehir, "Katılım onaylı"/"Üye" mini rozetler, sahip için "{N} bekleyen istek" pill'i ve durum-bazlı birincil CTA.

| ID | Alan | Öncelik | Problem | Kullanıcı Etkisi | Önerilen Çözüm | Kod Değişikliği Gerekir mi? |
|----|------|---------|---------|------------------|----------------|------------------------------|
| G-1 | Grup kartı kalitesi | — | Kartlar zaten kaliteli (gradient şerit, ikon, doluluk barı, rozetler). | Pozitif. Olduğu gibi korunmalı. | Değişiklik gerekmez. | Hayır |
| G-2 | Liste boş state | P2 | Grup yokken tek satır `PremiumCard` "Henüz grup yok" — düz, yönlendirme yok. | Yeni kullanıcı ne yapacağını bilmez. | "İlk grubu sen kur" CTA'lı zengin empty state (ikon + açıklama + buton). | Evet (UI) |
| G-3 | Arama sonuç state | P2 | Arama sonucu boşsa ayrı bir "sonuç bulunamadı" mesajı net değil; sonuç sayısı feedback'i yok. | Kullanıcı aramanın çalışıp çalışmadığını bilemez. | "X grup bulundu" / "'…' için sonuç yok" mikro-copy. | Evet (UI) |
| G-4 | Popüler/aktif vurgusu | P2 | `popularGroupsProvider` var ama liste ekranı popüler/aktif grupları öne çıkarmıyor. | "Buraya katılırsam değer alırım" hissi zayıflıyor. | "Popüler" / "Aktif" bölüm etiketi veya rozet. | Evet (UI) |

---

## Group Detail & Membership Flow

Grup detayı (`group_detail_screen.dart`) **chat-centric**: AppBar (grup adı + "{N} üye · Katılım onaylı" alt başlık + menü), mesaj listesi (Expanded), altta sticky composer veya katılma CTA. Özel grupta üye değilsen `_PrivateGated` (kilit + bilgi + istek butonu) görünüyor. Sahip için bekleyen istek uyarısı, üyeler sheet'i ve istek onay/ret sheet'i mevcut — akış bütünlüklü.

Üyelik akışı sağlam: public → `joinGroup` (`GroupJoinResult` ile success/full/alreadyJoined/notFound/requiresApproval mesajları), private → `requestJoinGroup` → sahip onayı. Ayrılma `leaveGroupSafely` ile sahiplik devri/kapanış outcome'larını doğru ele alıyor. Tüm yazma yolları `runGuardedMutation` + `GuestActionRequiredException` ile korunuyor.

| ID | Alan | Öncelik | Problem | Kullanıcı Etkisi | Önerilen Çözüm | Kod Değişikliği Gerekir mi? |
|----|------|---------|---------|------------------|----------------|------------------------------|
| G-5 | **Mesaj yazarı = "Misafir"** | **P0** | `GroupComposer._send()` mesajı `authorName: 'Misafir'` hardcoded ile gönderiyor (`group_detail_screen.dart:1353`). Gerçek kullanıcı adı çekilmiyor. | **Her grup mesajı "Misafir" yazarıyla görünüyor — kimlik/güven tamamen kırılıyor.** Topluluk hissi imkânsız. | Composer'da auth user → profil adı/rolü provider'dan okunup `GroupMessage`'a yazılması. | Evet (provider wiring) |
| G-6 | Topluluk alanı hissi | P1 | Detayda grup açıklaması, kuralları, üye avatar önizlemesi, aktivite/son hareket hissi yok — sadece başlık + sohbet. | Grup "liste ekranı + boş sohbet" gibi duruyor, "yaşayan topluluk" değil. | Sohbetin üstüne kompakt grup başlığı: açıklama + (varsa) kurallar + üye avatar yığını + "{n} üye, son hareket …". | Evet (UI) |
| G-7 | Üye/aktivite önizleme | P1 | Üye listesi yalnızca menü → sheet ardında; "kimler burada" hissi anlık değil. | Katılmadan önce grubun canlı olup olmadığı anlaşılmıyor. | Header'da üst 3-5 üye avatar yığını + toplam sayı. | Evet (UI) |
| G-8 | Composer gönderim feedback | P1 | Grup composer'da gönderiliyor/gönderildi state'i yok, buton hep aktif, optimistic echo yok; mesaj ancak provider refresh sonrası görünüyor. | Yavaş ağda "gitti mi?" belirsizliği; Messenger'a göre hantal. | Gönder anında optimistic ekleme + kısa "gönderiliyor" indikatörü; başarısızsa satır-içi retry. | Evet (UI + state) |
| G-9 | Mesaj zenginliği | P2 | Reaksiyon, yanıt/thread, düzenle/sil yok; `isPinned` rozet render ediliyor ama pin aksiyonu yok. | Sohbet "düz akış"; modern grup hissi eksik. | V2: en az reaksiyon + sahip pin aksiyonu. | Evet (sonraya) |

---

## Group Empty States & CTA

- **Mesaj boş state'i (detay):** `forum_outlined` ikon + "İlk mesajı sen yaz" + "Sohbet şu anda boş" — fena değil, net CTA tonu var.
- **Üye boş state:** "Bu grubun üyeleri henüz görünmüyor." — uygun (typo yok; doğrulandı).
- **Bekleyen istek boş:** "Katılım isteği yok" — uygun.
- **Liste boş / üye olunan grup boş:** düz tek-satır kart — zayıf (bkz. G-2).

| ID | Alan | Öncelik | Problem | Kullanıcı Etkisi | Önerilen Çözüm | Kod Değişikliği Gerekir mi? |
|----|------|---------|---------|------------------|----------------|------------------------------|
| G-10 | "Üye olduğum gruplar" boş | P2 | "Henüz bir gruba üye değilsin" düz metin; keşfe yönlendirme yok. | Yeni kullanıcı boşlukta kalır. | "Aşağıdan bir gruba katıl" mikro-yönlendirme + scroll hint. | Evet (copy) |

---

## Messaging Conversation List

`MessagesListScreen` (`features/messages/screens/`) — not: dosya `messages/` altında ama veriyi `messaging/` provider'larından okuyor (klasör adlandırması ters/karışık). Liste düzgün: `FirinNetHeader`, kart başına avatar (baş harf), ad, sağda relatif zaman ("şimdi/Xd/Xsa/Xg/d MMM"), bağlam rozeti ("Market ilanı"/"İş ilanı"/"İş arayan ilanı"), son mesaj önizleme (boşsa "—"), ve **bakır okunmamış badge** ("99+" cap'li). Boş state guest/auth ayrımı yapıyor.

| ID | Alan | Öncelik | Problem | Kullanıcı Etkisi | Önerilen Çözüm | Kod Değişikliği Gerekir mi? |
|----|------|---------|---------|------------------|----------------|------------------------------|
| M-1 | Liste kalitesi | — | Konuşma listesi modern ve okunabilir (avatar, zaman, bağlam rozeti, unread badge). | Pozitif. Korunmalı. | Değişiklik gerekmez. | Hayır |
| M-2 | Klasör/sistem ikiliği | P1 | İki paralel sistem: generic `messaging/` (canlı) + legacy `messages/` (job). `MessagesListScreen` `messages/`'ta ama `messaging/` okuyor. | Kullanıcı görmez; **dev tarafında bakım/karışıklık riski**, yanlış sisteme bağlama hatası. | Legacy'yi netçe emekliye ayır veya tek sisteme yakınsa; klasör adlandırmasını belgele. | Evet (refactor, sonraya) |
| M-3 | Presence/okundu işareti | P2 | Online/typing/okundu (çift tik) yok. | V1 için kabul edilebilir; uzun vadede eksik. | V2 referans. | Evet (sonraya) |

---

## Chat Screen & Message Composer

**Canlı ekran — `ChatScreen` (`features/messaging/`, `/messages/:id`):** `flutter_chat_ui ^2.11.1` (`fcu.Chat`) kullanıyor. initState'te mesajları çekip controller'a yüklüyor, realtime INSERT listener + `_seenMessageIds` dedupe, açılışta `markAsRead` RPC. `resolveUser` minimal `User(id)` dönüyor (bubble'da ad/avatar yok). AppBar karşı tarafın adını + bağlam alt başlığını gösteriyor.

**Legacy ekran — `JobConversationScreen` (`features/messages/`, `/messages/legacy/:id`):** Özel `ListView` + özel `_MessageBubble` (benim mesajım sağda primary@%8 arka plan + köşe asimetrisi, karşı taraf solda surface), per-mesaj timestamp, sil aksiyonu, "sohbet kapatıldı" banner'ı, **gönder butonunda loading spinner**, "Henüz mesaj yok. İlk mesajı sen yaz." boş state'i.

| ID | Alan | Öncelik | Problem | Kullanıcı Etkisi | Önerilen Çözüm | Kod Değişikliği Gerekir mi? |
|----|------|---------|---------|------------------|----------------|------------------------------|
| M-4 | **Markasız chat teması** | **P0** | Canlı `ChatScreen`, flutter_chat_ui'yi **hiç temalandırmadan** kullanıyor (`chat_screen.dart`'ta `theme:`/`ChatTheme` yok) → varsayılan mavi/gri bubble, FırınNet bakır/limon/krem kimliğiyle çelişir. | Ana mesajlaşma ekranı "premium" görünmüyor; legacy ekran ironik biçimde daha marka-uyumlu. | flutter_chat_ui'nin `theme`/builder API'siyle bubble/zemin/input'u marka token'larına bağla. **Yeni paket gerekmez — mevcut paketin tema yüzeyi kullanılmıyor.** | Evet (tema config) |
| M-5 | **Hata = mesaj kaybı** | **P0/P1** | `_onSend` hata yakalayınca sadece snackbar gösteriyor; flutter_chat_ui input'u zaten temizledi, başarısız mesaj korunmuyor/retry yok (`chat_screen.dart:110-116`). | **Ağ hatasında kullanıcının yazdığı mesaj kaybolur**, sadece geçici uyarı. Messenger'da bu olmaz. | Başarısız mesajı "gönderilemedi" bubble'ı olarak tut + dokunmatik retry; veya en az input'u geri doldur. | Evet (state + UI) |
| M-6 | Teslim göstergesi | P1 | `_sending` izleniyor ama UI'da görünmüyor; "gönderiliyor/gönderildi" indikatörü yok, realtime echo'ya güveniyor. | Yavaş ağda anlık feedback yok. | flutter_chat_ui durum/builder ile "gönderiliyor → gönderildi" göstergesi. | Evet (UI) |
| M-7 | Canlı chat boş state | P1 | `ChatScreen` boş konuşmada boş Chat alanı gösteriyor; legacy ekranın "İlk mesajı sen yaz." state'i var, canlı ekranda yok. | Boş sohbet yönlendirmesiz/soğuk. | flutter_chat_ui empty builder ile marka-uyumlu boş state. | Evet (UI) |
| M-8 | Legacy ekran erişilebilir | P1 | `/messages/legacy/:id` hâlâ canlı; girişe göre kullanıcı iki farklı chat UI'sıyla karşılaşabilir. | Tutarsız deneyim. | Legacy'yi tek noktadan kullanımdan kaldır veya generic'e köprüle. | Evet (router, sonraya) |
| M-9 | Tarih ayraçları | P2 | Canlı chat'te gün ayracı (bugün/dün) net değil (kütüphane davranışına bağlı). | Uzun sohbette okunabilirlik düşer. | flutter_chat_ui tarih ayracı yapılandırması. | Evet (config) |

---

## Message State: Sending / Sent / Failed / Unread

| Durum | Canlı `ChatScreen` (generic) | Legacy `JobConversationScreen` | Grup composer |
|-------|------------------------------|--------------------------------|----------------|
| Gönderiliyor | `_sending` var ama **görünmez** | Buton spinner'ı **var** + input disable | **Yok** (buton hep aktif) |
| Gönderildi | Realtime echo ile gelir (gecikme görünmez) | Provider invalidate ile gelir | Refresh sonrası gelir |
| Başarısız | Snackbar + **mesaj kaybı riski** | Snackbar; input korunur | Snackbar; input korunur (clear yalnız başarıda) |
| Okundu/okunmadı | `markAsRead` RPC açılışta; unread sayacı listede | Açık unread takibi yok | Yok |

**Sonuç:** En zayıf nokta canlı ekrandaki başarısız-gönderim davranışı (M-5) ve görünmez gönderim state'i (M-6). Grup composer'da hiç gönderim feedback'i yok (G-8). Legacy ekran bu konuda ironik biçimde en olgun olanı.

---

## Notifications / Unread Badges

- **Konuşma listesi:** bakır okunmamış badge ("99+" cap'li) — iyi.
- **Grup bildirim zili:** `NotificationsHeaderAction` + bekleyen istek badge'i — var.
- **Global/ambient unread badge: YOK.** `PremiumBottomNav` / `PremiumNavItem` hiç badge/count alanı içermiyor (`premium_bottom_nav.dart`); alt sekmede okunmamış göstergesi render edilmiyor.

| ID | Alan | Öncelik | Problem | Kullanıcı Etkisi | Önerilen Çözüm | Kod Değişikliği Gerekir mi? |
|----|------|---------|---------|------------------|----------------|------------------------------|
| M-10 | **Global unread badge yok** | **P1** | Alt nav badge desteklemiyor; unread yalnız konuşma kartı içinde. | Kullanıcı sekmeyi açmadan yeni mesajdan haberdar olmaz — Messenger'ın temel ambient sinyali eksik. | `PremiumNavItem`'a `badgeCount` ekleyip Mesajlar sekmesinde toplam unread göstermek. | Evet (UI + provider) |

---

## Guest Guard & Feedback

Guest guard **sağlam ve tutarlı**. `AuthRequiredGuard.canWrite()` mantığı net; tüm yazma yolları ya `runOrPrompt` ya `runGuardedMutation` ile sarılı; `GuestActionRequiredException` yakalanınca `showAuthRequiredSheet` açılıyor. Sheet kaliteli: bakır gradient ateş ikonu, "Hesabını oluştur, kaydın sende kalsın" başlığı, 3 CTA (Hesap oluştur / Giriş yap / Şimdilik gezmeye devam et). Okuma yolları guard'sız (guest gezebilir) — doğru tasarım.

| ID | Alan | Öncelik | Problem | Kullanıcı Etkisi | Önerilen Çözüm | Kod Değişikliği Gerekir mi? |
|----|------|---------|---------|------------------|----------------|------------------------------|
| GG-1 | Guard kalitesi | — | Guard + auth sheet kaliteli ve premium. | Pozitif. Korunmalı. | Değişiklik gerekmez. | Hayır |
| GG-2 | Composer içi guest copy | P2 | Grup composer'da `groupDetailComposeJoinedOnly` "katılınca yazabilirsin" tonu net; guest için ayrıca kısa teşvik eklenebilir. | Minör. | İsteğe bağlı mikro-copy. | Evet (copy) |

---

## Open Source Support Evaluation

**Kritik tespit: chat UI paketi zaten projede.** `pubspec.yaml`:

```yaml
flutter_chat_ui: ^2.11.1      # Apache-2.0
flutter_chat_core: ^2.9.0     # MIT
```

Canlı `ChatScreen` bunu kullanıyor (vendor kopya yok, backend bizim Supabase repository katmanımız).

| Soru | Cevap |
|------|-------|
| Hangi paket/pattern uygun? | **flutter_chat_ui (flyer.chat)** — zaten var, generic chat için kullanılıyor. |
| Lisans uygun mu? | Evet. Apache-2.0 + MIT, ikisi de permissive ve uyumlu. `THIRD_PARTY_LICENSES.md`/`THIRD_PARTY_NOTICES.md` mevcut. |
| Aktif bakım var mı? | Evet (flyer.chat aktif). 2.11.x güncel hat. |
| Flutter/Riverpod/Supabase yapımıza ters mi? | Hayır. UI katmanı; backend bizim. Riverpod ile sorunsuz. |
| Sadece UI component olarak mı? | Evet — `InMemoryChatController` + `resolveUser` + `onMessageSend` ile yalnız UI; veri bizden. |
| Paket mi, kendi component mi? | **Karma, ve zaten doğru kararı vermişiz:** generic chat = flutter_chat_ui (tema YETERSİZ kullanılmış), grup chat + konuşma listesi = kendi widget'larımız. |
| Hemen eklenmeli mi? | **Hayır — yeni hiçbir şey eklenmemeli.** Asıl iş: mevcut flutter_chat_ui'nin **tema + builder yüzeyini kullanmak** (M-4/M-6/M-7/M-9 bununla çözülür). |

**Değerlendirilen başlıklar:**
- *Chat UI package:* flutter_chat_ui (mevcut) — tema/builder'ları kullanılmıyor; en yüksek getirili iş bu.
- *Message bubble:* Legacy job ekranı zaten marka-uyumlu özel bubble içeriyor — referans olarak generic ekranın temalanmasında kullanılabilir.
- *Chat list virtualization / scroll:* flutter_chat_ui + Flutter `ListView` yeterli; ek paket gereksiz.
- *Swipe/long-press message action:* V2 için flutter_chat_ui'nin kendi etkileşim API'si referans alınmalı (yeni paket değil).
- *Top banner feedback:* Mevcut premium top banner sistemi yeterli.
- *Group/community UI:* Kendi `GroupCard` pattern'imiz iyi; topluluk-detay (G-6/G-7) için kendi component'imizi geliştirmek doğru — paket gereksiz.

**Kesin sonuç:** Yeni dependency YOK, fork YOK, kod kopyalama YOK. Tüm önerilen iyileştirmeler mevcut paket + kendi widget'larımızla yapılabilir.

---

## P0 Eksikler

| ID | Özet |
|----|------|
| **G-5** | Grup mesajı yazarı her zaman "Misafir" — hardcoded `authorName: 'Misafir'`. Kimlik/güven kırılıyor. (provider wiring) |
| **M-4** | Canlı `ChatScreen` markasız flutter_chat_ui varsayılan temasıyla — premium kimlik yok. (tema config) |
| **M-5** | Gönderim hatasında mesaj kaybolabiliyor; retry yok, sadece geçici snackbar. (state + UI) |

## P1 Polish Önerileri

| ID | Özet |
|----|------|
| G-6 | Grup detayı topluluk alanı gibi olmalı: açıklama + kurallar + aktivite hissi. |
| G-7 | Detay header'da üye avatar önizlemesi ("kimler burada"). |
| G-8 | Grup composer'da gönderim feedback + optimistic echo. |
| M-6 | Canlı chat'te görünür "gönderiliyor/gönderildi" göstergesi. |
| M-7 | Canlı chat boş state ("İlk mesajı yaz") — legacy'de var, canlıda yok. |
| M-8 | Legacy job chat ekranını emekliye ayır / köprüle (iki UI tutarsızlığı). |
| M-10 | Alt nav'da global okunmamış mesaj badge'i. |
| M-2 | `messaging/` vs `messages/` klasör/sistem ikiliğini belgele/yakınsa. |

## P2 Sonraya Bırakılabilir

| ID | Özet |
|----|------|
| G-2 / G-3 / G-4 | Liste boş state CTA'sı, arama sonuç feedback'i, popüler/aktif vurgu. |
| G-9 | Grup mesajlarında reaksiyon / yanıt / pin aksiyonu / düzenle-sil. |
| G-10 / GG-2 | "Üye olduğum gruplar" boş yönlendirmesi, composer guest mikro-copy. |
| M-3 | Presence / typing / okundu (çift tik). |
| M-9 | Canlı chat tarih ayraçları. |

---

## Önerilen Sprint Sırası

**Sprint A — Güven & Kimlik (P0):**
1. **G-5** Grup mesajı yazar adını gerçek kullanıcıdan al (provider wiring + composer).
2. **M-4** flutter_chat_ui'yi marka token'larıyla temalandır (bubble/zemin/input).
3. **M-5** Başarısız gönderimde mesajı koru + satır-içi retry (mesaj kaybını bitir).

**Sprint B — Canlılık & Feedback (P1):**
4. **M-6 + G-8** Görünür gönderim/teslim göstergesi (hem generic hem grup composer).
5. **M-7** Canlı chat boş state'i.
6. **M-10** Alt nav global unread badge.
7. **G-6 + G-7** Grup detay topluluk başlığı (açıklama + üye avatar önizleme + aktivite).

**Sprint C — Konsolidasyon & Zenginlik (P1/P2):**
8. **M-8 + M-2** Legacy job chat'i emekliye ayır; messaging klasör ikiliğini netleştir.
9. **G-2/G-3/G-4** Liste boş state + arama feedback + popüler vurgu.
10. **G-9 / M-3 / M-9** Reaksiyon/pin, presence, tarih ayraçları (V2).

> Tüm bu işler **yeni dependency olmadan** yapılabilir. En yüksek getiri/risk oranı: M-4 (tema), G-5 (yazar adı), M-5 (mesaj kaybı).

---

## Sprint A Sonucu — Trust, Identity, Branded Chat (2026-06-10)

Commit: `refactor(social): improve group identity and branded messaging quality`.
**Yeni dependency yok. Supabase schema/RLS/migration/route mimarisi değişmedi.** Mevcut `flutter_chat_ui` / `flutter_chat_core` paketlerinin tema + builder yüzeyi kullanıldı.

| ID | Önce | Sonra | Durum |
|----|------|-------|-------|
| **G-5** | `GroupComposer` mesajı `authorName: 'Misafir'` hardcoded ile gönderiyordu. | Yazar adı `profileControllerProvider` → profil `display_name`'inden gelir; boşsa `PublicProfile.fallbackName` ("FırınNet Kullanıcısı"). Owner mesajında rol "Kurucu". Guest yazma yolu zaten guard'lı, değişmedi. (Not: Supabase yolunda `author_name` zaten server-side trigger ile dolar; bu fix local/optimistic gösterim sözleşmesini düzeltir ve kör "Misafir"i kaldırır.) | ✅ **Kapandı** |
| **M-4** | Canlı `ChatScreen` flutter_chat_ui varsayılan (mavi/gri) temasıyla. | `_brandChatTheme()` — `ChatTheme.light()` üzerinden lemon-white-brandInk: gönderen bubble = `brandLemon` + `brandInk` metin, yüzey = beyaz, karşı taraf bubble = açık gri, köşe = `AppRadius.l`. | ✅ **Kapandı** (kontrollü tema; ağır redesign yapılmadı) |
| **M-5** | Hata → geçici snackbar, mesaj kaybolma hissi, retry yok. | Optimistic gönderim: `sending` → `sent`/`error`. Hatada bubble `error` durumunda kalır (**metin kaybolmaz**), üst şerit (`PremiumTopBanner` danger) "Tekrar dene" sunar; ayrıca error bubble'a dokununca resend. `_pendingText` ile metin saklanır. | ✅ **Kapandı** (UI feedback + retry). İlişkili **M-6** (gönderiliyor/gönderildi göstergesi) paket `MessageStatus` ile büyük ölçüde geldi. |
| **M-7** | Canlı chat boş state'i yoktu. | `emptyChatListBuilder` → marka-uyumlu `_ChatEmptyState`: "İlk mesajı sen yaz" + bağlam etiketi + lemon ikon. | ✅ **Kapandı** |

**Sprint A testleri:** `test/groups_messaging_sprint_a_test.dart` (source-contract) eklendi; mevcut `messaging_m1_2_ui_test.dart` sözleşmesi (`onMessageSend: _onSend`, `_toUiMessage`, `_seenMessageIds`, `markAsRead`, ...) korunarak doğrulandı. Toplam test 1241 → **1252**.

### Sprint A sonrası kalan işler
- **P1:** M-10 (global unread nav badge), G-6/G-7 (grup detay topluluk başlığı + üye avatar önizleme), G-8 (grup composer optimistic gönderim feedback'i — chat'teki desen grup composer'a da taşınabilir), M-8/M-2 (legacy job chat emekliye ayırma + klasör ikiliği).
- **P2:** G-2/G-3/G-4 (liste boş state CTA, arama feedback, popüler vurgu), G-9 (reaksiyon/pin/yanıt), M-3 (presence/typing/okundu), M-9 (tarih ayraçları).
- **Not (M-5 derinleştirme adayı):** Üst şerit retry 6 sn sonra kapanır; error bubble'a dokunarak retry kalıcıdır. İstenirse failed bubble'a kalıcı görünür "Tekrar dene" etiketi özel `textMessageBuilder` ile eklenebilir (ayrı P1). → **Sprint B'de yapıldı.**

---

## Sprint B Sonucu — Liveness, Unread Badges, Community Feel (2026-06-10)

Commit: `refactor(social): add group liveness and messaging feedback polish`.
**Yeni dependency yok. Supabase schema/RLS/migration/route mimarisi/membership logic değişmedi.** Sahte unread/üye/aktivite verisi üretilmedi.

| ID | Önce | Sonra | Durum |
|----|------|-------|-------|
| **M-10** | Okunmamış farkındalığı yalnız konuşma listesi kartında. (Not: alt nav'da **Mesajlar sekmesi yok**; giriş Panel kartından.) | `totalUnreadMessagesProvider` — `conversationsListProvider`'daki `unreadCount` toplamı (gerçek veri; yüklenmemişse 0, sahte sayı yok). `QuickActionTile`'a `badgeCount` desteği eklendi; Panel "Mesajlar" kartı premium lemon/brandInk badge gösterir ("9+" cap). | ✅ **Kapandı** (doğru yüzey = Panel kartı; nav sekmesi olmadığı için badge oraya bağlandı) |
| **G-6/G-7** | Grup detayı sade sohbet; açıklama/üye hissi yok. | Sohbetin üstünde kompakt `_GroupCommunityHeader`: grup **açıklaması** + gerçek **üye avatar önizlemesi** (`groupMembersProvider`, `_GroupAvatarStack`, ilk 5 + üye sayısı). Veri yoksa hiç çizilmez (boş kutu/sahte avatar yok). Chat ön planda kalır (büyük hero değil; UX-reset sözleşmesi korundu). | ✅ **Kapandı** (rules alanı için veri/şema yok → dürüstçe eklenmedi, P2 not) |
| **G-8** | Grup composer'da gönderim feedback yok; hata snackbar. | `_sending` state → buton spinner + disabled (duplicate guard). Hata → `PremiumTopBanner` (danger) "Tekrar dene" + **metin korunur** (temizlenmez). | ✅ **Kapandı** |
| **M-5 deepening** | Error sadece status indikatörü + üst şerit + tap-retry. | `textMessageBuilder` ile error bubble'ın altına **görünür satır-içi "Tekrar dene"** eklendi. `chatMessageBuilder` override edilmedi → hizalama/animasyon paket varsayılanından; default bubble `fcu.SimpleTextMessage` ile korunur (güvenli, layout riski yok). Aynı local mesaj üzerinden resend → duplicate riski yok. | ✅ **Kapandı** |

**Sprint B testleri:** `test/groups_messaging_sprint_b_test.dart` — QuickActionTile badge **widget testi** (görünür/gizli/9+) + source-contract. Mevcut `groups_v1_ux_reset_test.dart` / `groups_sprint1_owner_state_test.dart` / `messaging_m1_2_ui_test.dart` sözleşmeleri korundu. Toplam test 1252 → **1265**.

### Sprint B sonrası kalan işler
- **P1:** M-8/M-2 (legacy job chat emekliye ayırma + `messaging/` vs `messages/` klasör ikiliği — dikkatli refactor gerekir).
- **P2:** G-2/G-3/G-4 (liste boş state CTA, arama sonuç feedback, popüler/aktif vurgu), G-9 (reaksiyon/yanıt/pin aksiyonu), M-3 (presence/typing/okundu çift-tik), M-9 (tarih ayraçları), grup kuralları alanı (şema/`group rules` verisi gerektirir).
- **Data source note:** Gerçek-zamanlı unread artışı için `messagingChangesProvider` tick'i konuşma listesini tazeler; anlık (push'suz) güncel kalır. Push/badge OS entegrasyonu kapsam dışı (P1+).

---

## Sprint C — Messaging Consolidation Review (2026-06-10)

Commit: `docs(ux): audit messaging consolidation path`.
**Tür: AUDIT + düşük riskli cleanup.** Bu sprintte mesajlaşma backend/route/send/read/unread davranışı değiştirilmedi; legacy silinmedi; folder rename yapılmadı. Yalnız: bu doküman, yanıltıcı bir router yorumunun düzeltilmesi ve audit edilmiş gerçeği kilitleyen contract testleri eklendi.

### Aktif (canlı) messaging sistemi
`lib/features/messaging/` — **generic** sistem. Tablolar: `conversations` / `conversation_participants` / `messages`. Repo: `SupabaseMessagingRepository` (gerçek) / `LocalMessagingRepository` (demo), `GuardedMessagingRepository` ile sarılı. Ekran: `ChatScreen` (`/messages/:id`, flutter_chat_ui, Sprint A/B'de markalandı). `contextType` zaten `profile_direct` / `market_listing` / `job_offer` / `job_seek` destekler.

### Legacy / job messaging sistemi
`lib/features/messages/` — **karma klasör**:
- **Generic'e ait:** `MessagesListScreen` (`/messages`) — aslında `conversationsListProvider` (generic) okur. (Klasör adı yanıltıcı: generic liste `messages/`'ta, generic chat `messaging/`'te.)
- **Job'a ait (legacy):** `job_messaging_providers/repositories/models`, `JobConversationScreen` (`/messages/legacy/:id`), `StartJobConversationSheet`. Tablolar: `job_conversations` / `job_messages`. Repo: `SupabaseJobMessagingRepository` (gerçek) / `LocalJobMessagingRepository` (demo).

### Route haritası
| Route | Ekran | Sistem | Durum | Navigasyon kaynağı |
|-------|-------|--------|-------|--------------------|
| `/messages` | `MessagesListScreen` | generic (liste) | **Canlı** | Panel "Mesajlar" kartı |
| `/messages/:id` | `ChatScreen` | generic | **Canlı** | Liste tap, Market detay, Profil DM, **(+ job sheet — yanlış)** |
| `/messages/legacy/:id` | `JobConversationScreen` | job (legacy) | **Ölü route** | **Hiçbir yerden push yok** |

### Kullanıcı giriş noktaları
- **Panel → Mesajlar kartı** → `/messages` (generic liste). ✅ Tutarlı.
- **Market detay → "Satıcıya mesaj"** → `findOrCreateDirectConversation` (generic) → `/messages/:id`. ✅
- **Profil → "Mesaj"** → generic `findOrCreate` → `/messages/:id`. ✅
- **İlanlar (Jobs) → "İletişime geç"** (offer & seek) → `StartJobConversationSheet` → **job** `startForJobOffer/Seek` (job_conversations'a yazar) → ama `/messages/:id` (**generic**) ekranına push. ❌ **Uyumsuz.**

### Kod klasörü karmaşası
`messaging/` = generic; `messages/` = generic liste + job sistemi karışık. Generic LİSTE `messages/`'ta, generic CHAT `messaging/`'te → dev için kafa karıştırıcı (kullanıcı görmez).

### Risk tablosu
| ID | Alan | Problem | Risk | Önerilen Aksiyon | Bu Sprintte Yapılsın mı? |
|----|------|---------|------|------------------|--------------------------|
| C-1 | Job mesaj akışı | `StartJobConversationSheet` job_conversation yaratır ama **generic** `/messages/:id`'ye gider; ilk mesaj `job_messages`'ta kalır, kullanıcı **boş generic sohbete** düşer. İkinci mesaj generic `messages`'a FK ile düşebilir → gönderim hatası. | **P0 — veri/UX tutarsızlığı; job mesajları kullanıcıya görünmez.** | Sprint D: tercihen job sheet'i generic `findOrCreateDirectConversation(contextType:'job_offer'/'job_seek')`'e migrate et (generic zaten bu context'i destekliyor). Test kapsamıyla. | ❌ (raporlandı; davranış değişikliği audit kapsamı dışı) |
| C-2 | Legacy route | `/messages/legacy/:id`'ye in-app navigasyon yok → ölü route. | Düşük (kullanıcı erişemez) ama yanıltıcı router yorumu vardı. | Yanıltıcı yorum düzeltildi; route Sprint D'ye kadar korunur (job okuyucusu). | ✅ (yalnız yorum) |
| C-3 | Job conversation list | `myJobConversationsProvider` yalnız (ölü) `JobConversationScreen` + start sheet invalidate tarafından kullanılır; **hiçbir liste ekranı job konuşmalarını göstermez.** | P1 — job konuşmaları tamamen orphan. | C-1 migrate çözünce ortadan kalkar. | ❌ (C-1'e bağlı) |
| C-4 | Klasör ikiliği | Generic liste `messages/`'ta, generic chat `messaging/`'te. | Düşük (kozmetik, dev-facing). | C-1 sonrası job sistemi emekliye ayrılınca `MessagesListScreen`'i `messaging/`'e taşı. | ❌ (kozmetik; refactor riski) |

### Riskli dosyalar
`start_job_conversation_sheet.dart` (C-1 routing), `job_conversation_screen.dart` + `job_messaging_*` (orphan legacy), `messages_list_screen.dart` (klasör konumu).

### Güvenli cleanup adayları (bu sprint yapıldı)
- ✅ Audit (bu bölüm).
- ✅ `app_router.dart` yanıltıcı yorum düzeltmesi: legacy route'a in-app push olmadığı + job sheet'in şu an generic route'a gittiği (C-1) açıkça not edildi. **Route/builder satırları değişmedi.**
- ✅ `test/messaging_consolidation_audit_test.dart`: audit edilmiş mevcut gerçeği (route map, generic liste, job sheet mismatch) contract olarak kilitler → Sprint D bunu bilinçli değiştirir.

### Silinmemesi gerekenler
- `JobConversationScreen` + `job_messaging` repo/model/provider + `/messages/legacy/:id` route → C-1 kararı verilmeden silinmemeli (job_conversations gerçek veri yolunu okuyan tek ekran).
- `MessagesListScreen` (generic liste) — canlı.

### Önerilen konsolidasyon sırası (Sprint D+)
1. **C-1 (P0):** Job sheet'i generic `findOrCreateDirectConversation(otherUserId, contextType:'job_offer'/'job_seek', contextId: postId)`'e migrate et → job konuşmaları generic liste + chat'te görünür; ilk mesaj `sendTextMessage` ile generic'e yazılır. Market/Profil deseniyle aynı. Tam test.
2. C-1 doğrulandıktan sonra: `job_messaging` providers/repos/models + `JobConversationScreen` + `/messages/legacy/:id` route'u emekliye ayır/sil. (`job_conversations`/`job_messages` tablo/RLS dokunuşu ayrı, dikkatli bir DB sprintidir.)
3. Kozmetik (C-4): `MessagesListScreen`'i `messaging/` altına taşı.

### Sprint C kod değişikliği özeti
- **Davranış değişikliği yok.** `app_router.dart` yalnız **yorum** düzeltmesi (route/builder aynı). Yeni contract testi eklendi. Supabase/schema/RLS değişmedi.

---

## Sprint D Sonucu — C-1 Fix: Job Conversations → Generic Messaging (2026-06-10)

Commit: `refactor(messaging): route job conversations through generic messaging`.
**Supabase schema/RLS/migration/route mimarisi değişmedi. Yeni tablo/dependency yok. Legacy silinmedi.**

### C-1 (P0) — KAPANDI ✅
`StartJobConversationSheet` artık **generic** messaging sistemini kullanır:
- `messagingRepositoryProvider` (legacy `jobMessagingRepositoryProvider` bırakıldı).
- `findOrCreateDirectConversation(otherUserId: ilan sahibi, contextType: 'job_offer'|'job_seek', contextId: ilan id)` → **generic `conversations`** satırı açar/yeniden bulur (idempotent; RPC advisory-lock + dedup → duplicate yok).
- İlk mesaj **generic `sendTextMessage`** ile **`messages`** tablosuna yazılır (kaybolmaz).
- Kullanıcı **generic `/messages/:id` ChatScreen**'e gider → conversation tanınır, mesaj görünür.
- `MessagesListScreen` (generic `conversationsListProvider`) bu conversation'ı **artık gösterir**; Panel unread badge generic count ile uyumlu kalır.
- Self/own-post ve eksik-id erken kontrol edilir; guest → `AuthRequiredSheet`; hata → snackbar + sheet açık kalır (metin korunur, tekrar denenebilir).

**Doğrulama (Supabase MCP ile, schema değiştirmeden okundu):** `find_or_create_direct_conversation` RPC whitelist'i `('market_listing','profile_direct','job_offer','job_seek')` — job tipleri için `context_id` zorunlu, self-DM + eksik profil server-side reddedilir. Yani migration mevcut şemayla tam destekli.

### Davranış / risk tablosu
| ID | Önce | Sonra | Durum |
|----|------|-------|-------|
| C-1 | Job sheet job_conversation yaratıp generic boş sohbete düşürüyordu | Generic conversation + generic ilk mesaj + generic chat | ✅ Kapandı |
| C-3 | Job konuşmaları hiçbir listede görünmüyordu | Generic `MessagesListScreen` artık gösterir | ✅ (C-1 ile çözüldü) |

### Legacy sistem (bu sprintte korundu)
- `/messages/legacy/:id` route + `JobConversationScreen` + `features/messages/job_*` (repo/model/provider) **silinmedi** (kural gereği). `job_messaging_v1_test.dart` legacy repo testleri hâlâ geçiyor.
- Artık **hiçbir kullanıcı-açık akış** legacy job sistemine yazmıyor (sheet generic'e taşındı). Legacy tamamen atıl.

### Sprint E için legacy emeklilik planı (öneri)
1. (İzleme) Yeni job konuşmalarının generic'te açıldığını prod'da doğrula.
2. `StartJobConversationSheet` dışında legacy job_messaging'e referans kalmadığını teyit et (zaten yok).
3. `JobConversationScreen` + `/messages/legacy/:id` route + `job_messaging_*` (repo/model/provider) + ilgili testleri kaldır.
4. (Ayrı, dikkatli DB sprinti) `job_conversations` / `job_messages` tablo + RLS emekliliği — eski veri taşıma/arşiv kararıyla.
5. Kozmetik (C-4): `MessagesListScreen`'i `messaging/` altına taşı.

### Sprint D kod değişikliği özeti
- `start_job_conversation_sheet.dart`: generic messaging'e bağlandı (import + `_onSendPressed` + doc).
- `messaging_consolidation_audit_test.dart`: C-1 contract'ı "FIXED" olarak güncellendi (generic wiring kilitlendi).
- **Generic send/read/unread davranışı değişmedi** (mevcut `findOrCreateDirectConversation` + `sendTextMessage` kullanıldı). Supabase/schema/RLS değişmedi.

---

## Sprint E Sonucu — Safe Legacy Job Chat Retirement (2026-06-10)

Commit: `refactor(messaging): retire legacy job chat surface`.
**Yalnız kod temizliği. Supabase schema/RLS/migration değişmedi; `job_conversations`/`job_messages` DB tabloları DROP EDİLMEDİ. Panel/bottom nav/navigation redesign yapılmadı. Yeni dependency yok.**

### Legacy kullanım analizi (silmeden önce)
- `/messages/legacy/:id` route'una **hiçbir in-app navigasyon yoktu** (Sprint C/D'de doğrulandı; Sprint D sonrası job sheet generic'e geçti).
- Legacy küme **kendine kapalıydı**: `app_router`(route+import) → `JobConversationScreen` → `job_messaging_providers` → `{job,local,supabase,guarded}_job_messaging_repository` → `{job_conversation, job_message}` modelleri. Hiçbir canlı UI/provider okumuyordu (sheet ve jobs_screen yalnız `StartJobConversationSheet` adını paylaşıyordu — generic giriş widget'ı).
- `flutter analyze` silme sonrası temiz → dangling referans yok (kümenin izole olduğunu doğruladı).

### Kaldırılanlar (kod)
| Tür | Dosya |
|-----|-------|
| Route | `/messages/legacy/:id` (app_router.dart) + `job_conversation_screen.dart` import |
| Ekran | `lib/features/messages/screens/job_conversation_screen.dart` |
| Provider | `lib/features/messages/providers/job_messaging_providers.dart` |
| Repository | `job_messaging_repository.dart`, `local_job_messaging_repository.dart`, `supabase_job_messaging_repository.dart`, `guarded_job_messaging_repository.dart` |
| Model | `job_conversation.dart`, `job_message.dart` |
| Test | `job_messaging_v1_test.dart` — silinen Dart koduna bağlı model/repo grupları kaldırıldı; **Migration-SQL smoke + UI wiring smoke korundu/güncellendi** |

### Korunanlar (silinmedi) ve nedeni
- **`job_conversations` / `job_messages` DB tabloları + RLS + `supabase/migrations/...job_messaging_v1.sql`** → backend/veri etkisi; kural gereği drop edilmedi. `job_messaging_v1_test.dart` migration-SQL smoke testleri bu dosyayı hâlâ doğruluyor.
- **`StartJobConversationSheet`, `JobOfferPost`, `JobSeekPost`, `MessagesListScreen`, `ChatScreen`** → canlı generic sistemin parçası.

### Generic sistem tek canlı sistem mi?
✅ **Evet.** Tüm kullanıcı-açık mesajlaşma artık generic: Profil DM, Market ilanı, Job offer, Job seek → hepsi `findOrCreateDirectConversation` + `sendTextMessage` + `/messages/:id` `ChatScreen`. Legacy yüzey koddan kalktı. Doğrulanan akışlar (regresyon yok): liste, chat, unread badge, failed retry, empty state.

### `job_conversations`/`job_messages` DB tabloları için sonraki karar
Ayrı, dikkatli bir **DB sprinti**: eski veri arşiv/taşıma kararı verildikten sonra tablo+RLS emekliliği. Bu sprintte/Flutter tarafında yapılmaz.

### Panel / bottom nav
**Değiştirilmedi** (kural gereği). Mesajlar girişi Panel kartı olarak kalıyor; nav redesign sonraya bırakıldı.

### Sprint E kod değişikliği özeti
- 8 legacy dosya silindi + app_router legacy route/import/yorum temizlendi.
- 3 test güncellendi (legacy "korunur" → "kaldırıldı" contract'ı; job_messaging_v1 dead-code grupları çıkarıldı). Toplam test 1274 → **1261** (silinen dead-code testleri; regresyon değil).
- Supabase/schema/RLS değişmedi; DB tabloları korundu.

---

## Sprint F — Group Chat Media & Community Richness Review (2026-06-10)

Commit: `docs(ux): audit group chat media and community richness`.
**Tür: AUDIT.** Medya implementasyonu yapılmadı; schema/RLS/storage/route/nav değişmedi; yeni dependency eklenmedi; "medya yakında" gibi ürün sözü verilmedi.

### Group Chat Media Current State
Grup sohbeti **tamamen metin tabanlı** — hiçbir katmanda medya yok:
- **Model** (`group_message.dart`): `id, groupId, authorName, authorRole, text, createdAt, isPinned, reactionCount`. **mediaUrl/mediaType/attachments YOK.**
- **DB** (`group_messages`, Supabase MCP ile salt-okuma doğrulandı): `id, group_id, owner_id, text, author_name, author_role, is_deleted, created_at, updated_at`. **Medya kolonu YOK.** (`is_pinned`/`reaction_count` kolonu bile yok; model'deki `isPinned` daima `false` map'lenir.)
- **Repository** (`supabase_social_group_repository`): insert yalnız `group_id/owner_id/text`; `_messageColumns` medya içermez.
- **Composer** (`GroupComposer`): tek satır `TextField` + gönder butonu. **Attach (📎/🖼️) butonu YOK.**
- **UI** (`_ChatBubble`): yalnız metin + avatar + timestamp + (atıl) pin rozeti. Image/video render YOK.
- **Local repo**: medya alanı yok.

**Mevcut medya altyapısı (BAŞKA modüllerde, gruba bağlı değil):** `image_picker ^1.1.2`, `cached_network_image ^3.4.1`, `video_player ^2.9.2`, `chewie ^1.8.5` zaten dependency. Upload/render: `avatar_upload_service`, `feed_media` + `supabase_feed_repository` (storage upload), `social_stories`, `market_listing_media`. **Hepsi feed/market/stories/avatar için; grup chat bunların hiçbirine bağlı değil.** Grup chat ayrıca `flutter_chat_ui` **kullanmaz** (custom liste) → paketin `ImageMessage`/`VideoMessage` builder'ları gruba uygulanamaz (yalnız generic `/messages` DM'i için geçerli).

### Image Support Verdict — **HAYIR (desteklenmiyor)**
Resim göndermek için gerekenler (hepsi bu sprintte yasak kapsamda):
1. **Schema:** `group_messages`'a medya kolonları (`media_url`, `media_type`, `media_width/height`) **veya** ayrı `group_message_media` tablosu (feed_media deseni).
2. **Storage:** grup-kapsamlı bir bucket + **RLS policy** (yalnız grup üyesi okur/yazar; private grup gating'i).
3. **Repository:** insert/read medya alanı + upload akışı.
4. **Composer:** attach butonu (`image_picker` reuse).
5. **UI:** image bubble (`cached_network_image` reuse) + full-screen viewer.
- **Dependency: YENİ GEREKMEZ** (picker/cached image/video zaten var). Asıl blocker **schema + storage + RLS**.
- **Closed-beta blocker mı?** Hayır — metin sohbeti çalışıyor. **P1** (FırınNet için ürün foto'su/ekmek görseli paylaşımı topluluk değerini ciddi artırır; sektörel bir community için image en yüksek getirili eksik).

### Video Support Verdict — **HAYIR (desteklenmiyor); image'dan sonra**
- Image'ın tüm gereksinimleri + ek maliyet: video upload (büyük dosya), thumbnail üretimi, playback (`video_player`/`chewie` var ama gruba bağlı değil), bellek/akış maliyeti, storage kotası.
- **Öneri:** önce image; video **P2** (image altyapısı oturduktan sonra). İlk etapta video implement edilmemeli.

### Storage / Schema / RLS Requirements (ayrı sprint)
| Gereksinim | Detay | Risk |
|-----------|-------|------|
| Schema | `group_messages` medya kolonları **veya** `group_message_media` tablosu | Migration; geri-uyumluluk dikkatli |
| Storage | Grup medya bucket + path düzeni (`group/<id>/...`) | Yeni bucket |
| RLS | Bucket policy: grup üyeliği + private gating; tablo medya kolonu RLS'i mevcut mesaj policy'leriyle hizalı | Yanlış policy = sızıntı riski → titiz review |
| Cleanup | Mesaj/ grup silininca medya orphan temizliği | Storage lifecycle |

### UI Requirements
- Composer: attach ikonu + seçili medya önizleme + gönderim sırasında progress (mevcut `image_picker` + Sprint A/B sending-state deseni reuse).
- Bubble: image için `cached_network_image` + tap → full-screen viewer (feed viewer deseni reuse).
- Empty/error: yükleme hatası state'i (Sprint A/B failed-retry deseniyle hizalı).

### Community Richness Gaps (audit)
| ID | Alan | Öncelik | Mevcut Durum | Risk | Önerilen Aksiyon |
|----|------|---------|--------------|------|------------------|
| F-1 | Grup chat **medya (image)** | P1 | Yok (model/DB/UI/composer hiçbiri desteklemiyor) | Schema+storage+RLS gerekir | Ayrı "Group Media V1 (image)" sprinti; dependency yok, RLS titiz |
| F-2 | Grup chat **video** | P2 | Yok | Yüksek maliyet | Image'dan sonra ayrı sprint |
| F-3 | **Grup kuralları / "neler paylaşılır?"** | P2 | Yok (veri/şema yok) | Şema gerekir (groups.rules kolonu) | Group Community V2; sahte kural üretme |
| F-4 | **Pinned duyuru** | P2 | Model'de `isPinned` var ama **DB kolonu yok**, pin aksiyonu/UI yok (atıl) | Schema (`is_pinned`) + RPC | Group Community V2 |
| F-5 | Grup detay **topluluk hissi** | P1→kısmen kapalı | Sprint B header (açıklama + üye avatar) var; aktivite/son-hareket hissi sınırlı | Düşük | Son mesaj zamanı/aktif üye göstergesi (gerçek veriyle) |
| F-6 | Empty state / **ilk paylaşım CTA** | — | "İlk mesajı sen yaz" + "Sohbet şu anda boş" mevcut (test'le kilitli) | — | Yeterli; medya gelince "fotoğraf paylaş" eklenebilir |
| F-7 | Grup arama/filtre | — | Liste: arama + kategori chip + üye olduğum carousel mevcut | — | Yeterli; P2 sonuç-sayısı/popüler vurgu (G-3/G-4) |
| F-8 | Reaksiyon / yanıt | P2 | Yok (`reactionCount` atıl) | Schema | Group Community V2 |

### Open-source / mevcut komponent değerlendirmesi
- **Yeni paket gerekmez.** `image_picker` (seçim), `cached_network_image` (render), `video_player`+`chewie` (video) zaten dependency.
- **Reuse:** Feed/stories upload pipeline (`supabase_feed_repository` storage upload, `avatar_upload_service`) **pattern** olarak reuse edilebilir; ama grup medyası **kendi bucket'ı + grup-kapsamlı RLS'i** ister (feed bucket'ı erişim kapsamı farklı, körlemesine reuse edilmez).
- **flutter_chat_ui media:** yalnız generic `/messages` DM'i için geçerli (grup chat custom). Grup için **kendi hafif image bubble** component'i (cached_network_image ile) en güvenlisi.
- **Fork gerekmez.**

### Recommended Sprint Order
1. **Group Media V1 — Image (P1):** schema (medya kolonları/tablo) + grup-kapsamlı storage bucket + RLS → repository → composer attach → image bubble + viewer. Yeni dependency yok. (RLS review kritik.)
2. **Group Community V2 (P2):** grup kuralları (`groups.rules`), pinned duyuru (`is_pinned` + RPC), reaksiyon. Schema gerektirir.
3. **Group Media V2 — Video (P2):** image oturduktan sonra; thumbnail + playback + storage kotası planıyla.
4. **Cosmetic (C-4):** `MessagesListScreen` → `messaging/` klasörü.

### Sprint F kod değişikliği özeti
- **Kod/davranış değişikliği YOK** (audit-only). Grup empty/first-post copy'leri `groups_v1_ux_reset_test` ile kilitli olduğundan ve net bir gereksinim doğmadığından dokunulmadı (gereksiz risk alınmadı). Supabase/schema/RLS/storage değişmedi; yeni dependency yok.

---

## Sprint G — Group & Messaging Media Attachments (image V1) (2026-06-10)

Commit: `feat(messaging): add image and video attachments to chats`.
Kullanıcı kararları: **private bucket + signed URL**, **migration dosyası (prod'a uygulama YOK)**, **image-first** (video sonraki sprint). **Yeni dependency yok.**

### Hangi schema seçildi?
- **Generic:** mevcut `public.messages.attachments jsonb` **reuse** edildi (yeni tablo yok). `message_type` **'text' kalır** → hardened `messages_insert_sender` policy ve `content 1..4000` CHECK'ine dokunulmadı. Resim `attachments.media_type='image'` ile tespit edilir; `content` = caption veya `📷 Fotoğraf` placeholder.
- **Group:** `public.group_messages`'a tek `attachments jsonb` kolonu eklendi; member-gated insert RLS aynı kaldı.
- **Gerekçe:** ayrı medya tabloları yerine mevcut/eklenen jsonb → en az şema yüzeyi, en az yeni RLS, mevcut hardening korunur. Migration: `supabase/migrations/20260610170000_chat_media_v1.sql` (yalnız repo; deploy/review'da uygulanır).

### Hangi bucket/path seçildi?
- **Private bucket `chat-media`** (`public=false`). Render **signed URL** ile (`createSignedUrl`, 1 saat).
- Path: `conversations/{conversationId}/{ownerId}/m_{ts}.{ext}` ve `groups/{groupId}/{ownerId}/m_{ts}.{ext}`.

### Image / Video destek durumu
- **Image: ÇALIŞIR (V1).** Generic ChatScreen + grup composer'da medya ikonu → bottom sheet (Galeriden seç / Fotoğraf çek) → upload → bubble + fullscreen viewer.
- **Video: KAPSAM DIŞI (bu sprint).** image-first kararı; video (upload/playback/thumbnail/limit) ayrı sprint. Picker sheet 2 image seçeneğiyle açıldı; video seçenekleri V1.1'de aynı sheet'e eklenecek.

### Generic messaging media
- `MessagingRepository.sendImageMessage` (supabase+local+guarded). `listMessages`/realtime → signed URL enrich. `ChatScreen.onAttachmentTap` flutter_chat_ui default composer'da attach ikonu açar; resim `fcc.ImageMessage` ile render; tap → fullscreen.

### Group chat media
- `SocialGroupRepository.postMessage` `GroupMessage.attachments` ile resim yazar (yeni interface metodu yok). `listMessages` signed URL enrich. Composer'da `add_photo_alternate` ikonu → sheet → upload → post; `_GroupImageBubble` (cached_network_image) + tap → fullscreen.

### Upload / retry / error davranışı
- Gönderim sırasında **persistan "Fotoğraf gönderiliyor…" üst şeridi** (optimistic in-bubble preview yerine — V1 sade/robust; in-bubble preview = polish notu).
- **Mesaj kaybı yok + duplicate yok:** mesaj satırı **yalnız upload+insert başarısında** eklenir; başarısızlıkta hiç satır yazılmaz → "Tekrar dene" aynı dosyayla yeniden dener, duplicate üretmez.
- Hata türleri: çok büyük (>10MB) / desteklenmeyen tür → uyarı şeridi; izin reddi → uyarı; guest → `AuthRequiredSheet`; ağ hatası → danger + retry.
- Validation: ≤10MB, jpg/png/webp.

### RLS / storage policy notları
- `storage.objects` `chat-media` için: **SELECT** = participant (`is_in_conversation`) veya grup üyesi (`group_members.owner_id=auth.uid()`); **INSERT** = owner segmenti (`foldername[3]=auth.uid()`) + üyelik; **UPDATE/DELETE** = owner. Bucket private → signed URL yalnız SELECT yetkisi olana üretilir.
- **Privacy:** private grup/DM medyası yalnız üye/participant'a görünür (public bucket sızıntısı yok).

### Kalan riskler
- Migration **prod'a uygulanmadı** (karar gereği) → medya akışı deploy + RLS review sonrası canlanır; o ana dek text sohbet etkilenmez. Manuel upload smoke prod migration uygulanınca yapılmalı.
- `createSignedUrl` 1 saat expiry; uzun açık kalan ekranda yenileme provider refresh ile olur (V1 kabul).
- Orphan storage objesi: upload başarılı ama insert başarısız olursa (nadir) orphan kalır → ileride cleanup job (P2).
- Video thumbnail/compression: **sonraya kaldı** (Sprint Media V1.1).

### Sprint G kod değişikliği özeti
- Eklenen: migration, `ChatMediaUploadService`, `ChatMediaPickerSheet`, Message/GroupMessage image getter'ları, generic+grup repo image yolu, ChatScreen + GroupComposer medya UI, `_GroupImageBubble`, AppStrings, `chat_media_v1_test.dart`.
- Supabase **schema/RLS/storage CANLI'ya uygulanmadı** (migration dosyası). Generic text send/read/unread davranışı değişmedi. Yeni dependency yok.

---

## Media V1 Deploy & RLS Verification (2026-06-10)

Commit: `chore(media): verify chat image storage and rls deployment`.

### Migration review sonucu — GÜVENLİ
- `messages.attachments` reuse: kolon mevcut, nullable, `message_type='text'` korunur → eski text mesajlar bozulmaz, veri migration gerekmez.
- `group_messages.attachments`: `add column if not exists ... jsonb` — nullable, default/CHECK yok → eski satırlar NULL, tam geriye uyumlu.
- Risky constraint yok; idempotent (`if not exists` / `drop policy if exists` / `on conflict do nothing`).
- **RLS düzeltmesi:** grup SELECT policy, `group_messages_select_visible` ile birebir hizalandı (public→authenticated, private→owner/üye) → medya görünürlüğü mesaj görünürlüğüyle tutarlı (public grupta üye-olmayan da görür). Generic = `is_in_conversation` (participant). INSERT = owner segment (`foldername[3]=auth.uid()`) + üyelik/participant. UPDATE/DELETE = owner. Guest (anon) → policy yok → deny.
- chat-media'yı açan catch-all storage policy **yok** (mevcut policy'ler bucket-scoped) → private bucket default-deny.

### Bucket / policy sonucu
- Bucket `chat-media`: **public=false** (private). ✓
- Storage policies: `chat_media_storage_{select,insert,update_owner,delete_owner}` oluştu. ✓
- Path-parsing: `storage.foldername` → `[scope, scopeId, ownerId]`, policy [1]/[2]/[3] indexlemesiyle birebir (SQL ile doğrulandı). `is_in_conversation` + `is_group_member` helper'ları mevcut. ✓

### Apply edildi mi? Hangi project?
- **Evet — apply edildi.** Project: **`sjeqwiqgwzagengdukye`** (`https://sjeqwiqgwzagengdukye.supabase.co`, FırınNet production; MCP'de bağlı tek proje, apply öncesi doğrulandı). MCP `apply_migration` (`chat_media_v1`) → `{success:true}`.
- Apply sonrası readonly doğrulama: bucket private ✓, `group_messages.attachments jsonb` ✓, 4 storage policy ✓.

### Generic chat upload smoke sonucu
- **End-to-end (gerçek foto seç/çek → upload → render) otomatize EDİLEMEDİ:** `image_picker` native galeri/kamera Flutter view'ı dışında; Patrol/otomatik test native picker'ı süremiyor → **manuel QA adımı**. Backend (bucket+RLS+kolon) + kod yolu + path-parsing doğrulandı; gerçek upload manuel test gerektirir.

### Group chat upload smoke sonucu
- Aynı: backend + kod hazır ve doğrulandı; gerçek foto seçimi manuel QA. Non-member upload yolu storage INSERT RLS + composer guard (yalnız owner/üye) ile çift kapalı.

### Kalan riskler
- **Manuel upload smoke yapılmadı** (native picker otomasyon dışı) → ilk gerçek QA'da generic + grup için galeri/kamera upload + signed-URL render + fail/retry doğrulanmalı.
- Live çok-kullanıcılı RLS smoke (participant okur / non-member okuyamaz) servis-rolü MCP ile yapılamaz → policy tanımı + statik review ile doğrulandı; canlı doğrulama manuel QA.
- Signed URL 1 saat expiry; orphan storage (upload-ok/insert-fail) → cleanup job (P2).

### Video V1.1 notları
- Bu sprintte video **yok** (kural). V1.1: picker sheet'e video seç/çek + `video_player`/`chewie` playback + boyut limiti; `attachments.media_type='video'` + thumbnail (opsiyonel). Mevcut storage RLS/bucket video için de geçerli (media_type ayrımı UI'da).

---

## Media V1 — P0 Auth Regression Fix (logged-in treated as guest) (2026-06-10)

Commit: `fix(media): preserve authenticated session during image upload failures`.

### Root cause
Guard'lar (`canWriteCheckProvider`, `AuthRequiredGuard.canWriteWithRef`) yazma yetkisini **cache'li `currentAuthUserProvider`** üzerinden ölçüyordu. Bu provider `authUserStreamProvider` (`onAuthStateChange`) emit'lerine bağlı; **emitler arası değeri cache'li**. Native image picker (galeri/kamera) FlutterActivity'yi arka plana atıp resume ettiğinde supabase_flutter geçici bir null-session/tokenRefresh event'i emit edebiliyor → cache `null` oluyor (oysa persist edilmiş session sağlam: `client.auth.currentUser` dolu). Sonuç: logged-in kullanıcı upload anında **guest** sanılıyor → guarded `sendImageMessage`/`postMessage` `GuestActionRequiredException` → `showAuthRequiredSheet` ("hesap gerekli") → sheet CTA login/role-select'e push → kullanıcı "signOut oldum / atıldım" hissi.

**Önemli:** Upload/profile-hydrate path'inde **gerçek `signOut()` çağrısı YOK**. signOut yalnız auth_actions, create_profile "misafir devam et" (Senaryo 2) ve hesap silme akışlarında — hiçbiri upload tarafından tetiklenmiyor. "signOut" tamamen yanlış-guard'ın downstream yan etkisiydi.

### Fix (minimal, auth refactor yok, schema/RLS değişmedi)
1. `canWriteCheckProvider` → `currentUser: ref.read(authRepositoryProvider)?.currentUser` (her çağrıda **canlı** `client.auth.currentUser` getter'ı; persist session). Tüm guarded write'lar (text dahil) artık geçici stream null'ına dayanıklı.
2. `AuthRequiredGuard.canWriteWithRef` → aynı canlı getter.
3. Upload path'leri (`chat_screen._uploadAndSend`, `group_detail._uploadAndPost`): owner uid'si canlı session'dan (`authRepository.currentUser.id` = `auth.uid` ile tutarlı → storage owner-segment RLS uyumlu). Live uid **gerçekten null** ise → `showAuthRequiredSheet` (case C); **signOut yok**.

### Davranış matrisi (sonuç)
- currentUser var + upload başarılı → resim gönderilir. ✓
- currentUser var + storage/RLS/network hatası → `chatMediaSendError` retry banner; session korunur; auth-required'a map EDİLMEZ; signOut yok. ✓
- currentUser yok → AuthRequiredSheet; signOut çağrılmaz. ✓
- Guest (guestMode) → guard hâlâ çalışır. ✓
- Text mesaj davranışı değişmedi (aynı guard daha dayanıklı). ✓

### Değişen dosyalar
`can_write_check_provider.dart`, `auth_required_guard.dart`, `messaging/screens/chat_screen.dart`, `social_groups/screens/group_detail_screen.dart` + `test/media_auth_regression_test.dart`. **Supabase schema/RLS/migration/production data değişmedi.**

---

## Media V1 — P0 Regression-of-Regression Fix: narrow the auth guard (2026-06-10)

Commit: `fix(media): scope live-session auth check to media upload paths only`.

### Sorun
`f9be952` guard'ı **global** olarak (`canWriteCheckProvider` + `canWriteWithRef`) cache'li `currentAuthUserProvider` yerine canlı `authRepository.currentUser` getter'ına çevirmişti. Bu, **normal text mesaj gönderimini** de etkiledi: logged-in kullanıcı text gönderirken "hesap gerekli" guard'ı aldı.

### Kök neden (hangi satır)
`f9be952` iki satırı değiştirmişti:
- `can_write_check_provider.dart`: `currentUser: ref.read(currentAuthUserProvider)` → `ref.read(authRepositoryProvider)?.currentUser`. **Text gönderimini bozan tam satır budur** (text → `GuardedMessagingRepository.sendTextMessage` → `canWriteCheck()` → bu provider).
- `auth_required_guard.dart::canWriteWithRef`: aynı değişiklik.

Mekanizma: soğuk başlangıçta `client.auth.currentUser` getter'ı session storage'dan async restore tamamlanana dek **geçici null** dönebilir; oysa stream-tabanlı `currentAuthUserProvider` `initialSession` event'iyle doğru değeri tutar. Yani canlı getter'ı global guard'a koymak genel yazımlar için (text dahil) daha kırılgandı.

### Fix — global geri alındı, canlı kontrol yalnız medyaya daraltıldı
- **Global guard geri alındı:** `canWriteCheckProvider` + `canWriteWithRef` yeniden cache'li `currentAuthUserProvider` okur → **text gönderimi son kanıtlı davranışa döndü** (tüm guarded yazımlar: text, grup mesajı, join, vb.).
- **Medya path'leri (yalnız `_uploadAndSend` + `_uploadAndPost`):** native picker resume'unda stale cache'i `ref.invalidate(currentAuthUserProvider)` ile persist session'dan tazele; owner uid'si `currentAuthUserProvider?.id ?? authRepository.currentUser?.id` (robust, **`local-user-me`/`''` fallback YOK**); ikisi de null ise → auth sheet (signOut yok). Guarded send tazelenmiş cache ile geçer.
- Fix **tüm yazımlara genişletilmedi**; yalnız iki medya metodu.

### Doğrulanan davranış
- Logged-in: generic chat **text** gönderir ✓ · grup **text** gönderir ✓ · generic chat **image** ✓ · grup **image** ✓ (kod yolu + guard mantığı; gerçek native upload manuel QA).
- Guest → auth guard ✓ · signOut yok ✓ · text davranışı değişmedi ✓ · schema/RLS değişmedi ✓.

### Değişen dosyalar (bu fix)
`can_write_check_provider.dart` (geri), `auth_required_guard.dart` (geri), `messaging/screens/chat_screen.dart` (medya: invalidate + robust uid), `social_groups/screens/group_detail_screen.dart` (medya: invalidate + robust uid), `test/media_auth_regression_test.dart` (güncellendi). **Onboarding/profile/createProfile/session redirect'e dokunulmadı.**

---

## Chat Media V1.1 — Video Attachments (2026-06-11)

Commit: `feat(media): add video attachments to chats`.

### Video picker seçenekleri
`ChatMediaPickerSheet` artık 4 seçenek döner (`ChatMediaPick {source, kind}`):
Galeriden seç / Fotoğraf çek (image) + Video seç / Video çek (video).
Video picker `image_picker.pickVideo` (galeri + kamera; kamera kaydı 60 sn
`maxDuration` ile sınırlı). Yeni dependency YOK — mevcut image_picker,
video_player ^2.9.2 ve chewie ^1.8.5 kullanıldı.

### Generic + Group video desteği
- Generic ChatScreen: `_uploadAndSend(file, kind)` → `chat-media` private
  bucket'a aynı path şemasıyla yükler; mesaj `media_type: video` attachments
  ile `sendImageMessage` üzerinden yazılır (message_type `text` kalır,
  content fallback `🎬 Video`). Render: `fcc.VideoMessage` +
  `videoMessageBuilder` (koyu yüzey + play overlay + "Video" etiketi);
  tap → `showChatVideoViewer` (SocialPostVideo/chewie dialog).
- Group chat: `_uploadAndPost(file, kind)` aynı akış; `_GroupVideoBubble`
  + aynı viewer. Üye gönderebilir, non-member/guest guard aynen geçerli
  (GuardedRepository + canWriteCheck değişmedi).
- Signed URL enrich her iki repo'da `hasImage || hasVideo` için çalışır.
- Bilinmeyen `media_type` → her iki yüzeyde text bubble fallback; eski
  image/text mesajlar değişmedi.

### Storage / schema / RLS
DEĞİŞMEDİ. Mevcut `chat-media` private bucket + `messages.attachments` /
`group_messages.attachments` jsonb + membership-gated storage RLS aynen
kullanıldı; migration yok.

### Video limitleri
- Boyut: **25 MB** (image 10 MB değişmedi). Gerekçe: free-tier storage +
  mobil veri dengesi; 50 MB upload süresi açısından riskli görüldü.
- Tür: mp4 (`video/mp4`) + mov (`video/quicktime`).
- Aşımda `ChatMediaTooLargeException` → "Video çok büyük (en fazla 25 MB)"
  banner'ı; desteklenmeyen türde "MP4 veya MOV seç" banner'ı. Mesaj
  kaybolmaz; genel hata banner'ında aynı dosyayla Tekrar dene var.
- Duration kontrolü P2 (yalnız kamera kaydı 60 sn ile sınırlı).

### Thumbnail / compression
P2'ye bırakıldı (yeni dependency eklenmemesi kuralı). Bubble: brand koyu
yüzey + play icon + "Video" etiketi. Compression yok; 25 MB limit koruyor.

### Kalan riskler
- Thumbnail olmadığı için bubble içerik önizlemesi vermiyor (P2).
- Çok yavaş bağlantıda 25 MB upload uzun sürebilir; banner persistent ama
  progress yüzdesi yok (P2).
- Video oynatma signed URL 1 saat geçerli; uzun açık kalan ekranda süre
  dolarsa "Video oynatılamadı" hata kutusu (yeniden açınca tazelenir).

### Manual smoke
Emülatörde kullanıcı tarafından doğrulanacak (text/image/video × generic/
group + background-foreground). Sonuç bu bölüme işlenecek.
