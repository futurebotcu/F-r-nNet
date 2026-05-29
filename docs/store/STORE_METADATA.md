# FırınNet — App Store Metadata (Draft)

> App Store Prep Sprint 1 çıktısı. App Store Connect web panelinde girilecek
> metinlerin Windows-safe taslağı. Submission öncesi gözden geçir + son hâli ver.
> İlgili: [REVIEW_NOTES_DRAFT.md](REVIEW_NOTES_DRAFT.md),
> [PRIVACY_LABEL_DRAFT.md](PRIVACY_LABEL_DRAFT.md),
> [APP_STORE_RUNBOOK.md](APP_STORE_RUNBOOK.md).

## Temel Bilgiler
| Alan | Değer |
|---|---|
| App Name | **FırınNet** |
| Bundle ID | `com.firinnet.firinDefter` |
| Version (marketing) | 0.1.0 |
| Build | 1 |
| SKU önerisi | `firinnet-ios-001` |
| Primary language | Turkish (tr) |

## Subtitle (max 30 karakter) — adaylar
- `Fırıncı sosyal ağı & defter` (27)
- `Fırın, ilan, reçete, defter` (27)

## Category
- **Primary:** Business
- **Secondary:** Social Networking *(alternatif: Productivity)*

## Keywords (max 100 karakter, virgülle)
```
fırın,fırıncı,ekmek,reçete,bayi defteri,usta,hamur,pastane,toptancı,ilan
```

## Promotional Text (max 170 karakter)
```
Fırıncılar, ustalar ve toptancılar için tek uygulama: sosyal akış, usta ilanları,
malzeme pazarı, reçete hesaplama ve bayi defteri. Kayıtsız gezmeye başla.
```

## Short Description / öne çıkan
```
FırınNet, fırıncıların mesleki sosyal ağı: paylaş, ilan ver, malzeme al-sat,
reçete hesapla ve bayi defterini tut.
```

## Long Description (taslak)
```
FırınNet, fırıncılar, fırın ustaları ve toptancılar için tasarlanmış mesleki bir
sosyal ağ ve işletme aracıdır.

• Akış: Meslektaşlarınla paylaş, yorum yap, beğen, kaydet ve hikaye yayınla.
• Usta Arıyor / İş İlanları: İşletmeler usta arar, ustalar iş ilanı oluşturur.
• Malzeme Pazarı: Un, maya, ekipman ve daha fazlasını al-sat.
• Reçete Hesaplama: Hamur miktarı, fire ve maliyet hesapla, reçeteni kaydet.
• Bayi Defteri: Teslimat, tahsilat ve bakiye takibini tek yerde tut.
• Fırın Paneli: Üretim ve fire kayıtlarını gir, gün sonu raporu al.

Kayıt olmadan "Kayıtsız devam et" ile keşfedebilir; hesap oluşturduğunda
içeriğin senin hesabına özel ve güvenli kalır (satır-bazlı güvenlik).
Ödeme/abonelik yoktur. Hesabını dilediğin an uygulama içinden silebilirsin.
```

## URL'ler
| Alan | URL | Durum |
|---|---|---|
| Privacy Policy URL | https://futurebotcu.github.io/F-r-nNet/privacy/ | ⚠️ GitHub Pages'in `docs/` köküyle yayında olduğunu teyit et |
| Account Deletion URL | https://futurebotcu.github.io/F-r-nNet/account-deletion/ | ⚠️ aynı teyit |
| Support URL | https://github.com/futurebotcu/F-r-nNet (geçici) | öneri: özel destek sayfası/e-posta |
| Marketing URL | (opsiyonel) | — |

> **Not (GitHub Pages):** Repo adı `F-r-nNet`. Pages `main`/`docs` ile servis
> ediliyorsa URL yapısı `…github.io/F-r-nNet/<path>/` olur. Yayında değilse
> Settings → Pages'ten açılmalı (web, write işlem — bu sprint dışı).

## Age Rating (tahmin)
- Kullanıcı üretimi içerik (UGC) + sosyal etkileşim → muhtemelen **12+**.
- Apple anketinde "User Generated Content: Yes" işaretlenmeli (bkz. review riskleri).

## Ödeme / IAP
- **Yok.** In-App Purchase, abonelik veya dijital satış yok. Anketlerde net belirt.

## Demo / Reviewer Erişimi
- Guest mode var ("Kayıtsız devam et") → reviewer login olmadan büyük kısmı görür.
- Tam özellik (yazma) için demo hesap önerilir; bkz. [REVIEW_NOTES_DRAFT.md](REVIEW_NOTES_DRAFT.md).
