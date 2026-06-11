// FırınNet UGC Safety V1 — şikayet modelleri.
//
// `content_reports.reason` ve `target_type` CHECK constraint'leriyle birebir
// aynı persist key'ler kullanılır (DB tek doğruluk kaynağı; bkz.
// supabase/migrations/20260611013000_ugc_safety_v1.sql).

/// Şikayet kategorileri — feed/yorum/grup/ilan/profil için ortak.
enum ReportReason {
  /// Spam / reklam kirliliği (tekrar eden içerik, link spam, sahte kampanya).
  spam('spam', 'Spam / reklam'),

  /// Hakaret, taciz, tehdit, ısrarlı rahatsız etme, hedef gösterme.
  harassment('harassment', 'Hakaret / taciz / tehdit'),

  /// Irk, din, milliyet, cinsiyet vb. temelli nefret ve ayrımcılık.
  hate('hate', 'Nefret / ayrımcılık'),

  /// Dolandırıcılık, sahte ilan, kapora tuzağı, yanıltıcı fiyat.
  scam('scam', 'Dolandırıcılık / sahte ilan'),

  /// Cinsel içerik, şiddet/gore, sektör bağlamına aykırı medya.
  inappropriateMedia('inappropriate_media', 'Uygunsuz medya'),

  /// Silah/uyuşturucu/kaçak ürün; gıda güvenliği açısından tehlikeli iddia.
  illegalOrDangerous('illegal_or_dangerous', 'Yasaklı / tehlikeli ürün'),

  /// Kişisel bilgi ihlali (izinsiz telefon/adres/görsel paylaşımı).
  privacy('privacy', 'Kişisel bilgi ihlali'),

  /// Diğer — kısa açıklama alanıyla.
  other('other', 'Diğer');

  const ReportReason(this.persistKey, this.label);

  /// DB CHECK constraint değeri.
  final String persistKey;

  /// Kullanıcıya gösterilen Türkçe etiket.
  final String label;
}

/// Şikayet edilebilir içerik türleri.
///
/// `direct_message` V1 kapsamı DIŞINDA (P2): DM içeriği gizlilik açısından
/// ayrı tasarım ister; V1'de gönderen kullanıcı `profile` üzerinden şikayet
/// edilebilir ve engellenebilir.
enum ReportTargetType {
  feedPost('feed_post'),
  comment('comment'),
  groupMessage('group_message'),
  marketListing('market_listing'),
  jobListing('job_listing'),
  profile('profile');

  const ReportTargetType(this.persistKey);

  final String persistKey;
}

/// Şikayet gönderiminin sonucu.
enum ReportResult {
  /// Yeni report kuyruğa alındı.
  submitted,

  /// Aynı kullanıcı aynı hedefi daha önce şikayet etmiş (duplicate guard).
  duplicate,
}

/// Engelleme sonucu.
enum BlockResult {
  blocked,
  alreadyBlocked,
}
