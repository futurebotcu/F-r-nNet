// B2B Pazar — Tedarikçi mağaza vitrini modeli (mock preview).
//
// FırınNet profilinin (BakeryProfile) birebir kopyası DEĞİL: ayrı ticari
// vitrin. Sahiplik yalnızca [isMine] ile mock olarak işaretlenir; gerçek
// AccountType / auth ile bağlanmaz (bu sprint preview toggle ile çalışır).
class B2bStore {
  const B2bStore({
    required this.id,
    required this.name,
    required this.monogram,
    required this.tagline,
    required this.description,
    required this.categories,
    required this.serviceRegions,
    required this.productCount,
    required this.campaignCount,
    this.isMine = false,
    this.logoUrl,
    this.coverUrl,
  });

  final String id;
  final String name;

  /// Logo yerine 1–2 harfli monogram (asset eklemeden vitrin kimliği).
  final String monogram;

  /// Kısa tanıtım satırı (kapak hissi için).
  final String tagline;

  /// Mağaza açıklaması (birkaç cümle).
  final String description;

  /// Sunulan ürün kategorileri (chip olarak gösterilir).
  final List<String> categories;

  /// Hizmet / teslimat bölgeleri.
  final List<String> serviceRegions;

  final int productCount;
  final int campaignCount;

  /// Mağaza logo görseli public URL'i (opsiyonel — canlı upload).
  final String? logoUrl;

  /// Mağaza kapak görseli public URL'i (opsiyonel — canlı upload).
  final String? coverUrl;

  /// Preview tedarikçinin kendi mağazası mı (mock sahiplik).
  final bool isMine;

  B2bStore copyWith({int? productCount, int? campaignCount}) {
    return B2bStore(
      id: id,
      name: name,
      monogram: monogram,
      tagline: tagline,
      description: description,
      categories: categories,
      serviceRegions: serviceRegions,
      productCount: productCount ?? this.productCount,
      campaignCount: campaignCount ?? this.campaignCount,
      isMine: isMine,
      logoUrl: logoUrl,
      coverUrl: coverUrl,
    );
  }
}
