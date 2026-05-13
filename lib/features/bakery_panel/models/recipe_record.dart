import 'recipe_metadata.dart';
import 'recipe_quantities.dart';
import 'recipe.dart';

/// Reçete görünürlüğü.
enum RecipeVisibility {
  /// Gizli — yalnız sahibi `Reçetelerim` ekranında görür.
  private,

  /// Profilde açık — sahibinin profil sayfasında "Açık Reçeteler"
  /// bölümünde diğer authenticated kullanıcılara görünür.
  public,
}

extension RecipeVisibilityX on RecipeVisibility {
  bool get isPublic => this == RecipeVisibility.public;
  bool get isPrivate => this == RecipeVisibility.private;

  String get badgeLabel {
    switch (this) {
      case RecipeVisibility.private:
        return 'GİZLİ';
      case RecipeVisibility.public:
        return 'PROFİLDE AÇIK';
    }
  }
}

/// Kayıtlı bir reçete: gerçek miktarlar + hesap çıktısı + zengin metadata
/// + görünürlük.
///
/// V1.1: kullanıcı yüzde değil gerçek miktar girer. [quantities] otoritedir;
/// Supabase `recipe_calculations` tablosundaki yüzde sütunları yalnız uyumluluk
/// için repository tarafında türetilir.
class Recipe {
  const Recipe({
    required this.id,
    required this.productName,
    required this.quantities,
    required this.result,
    required this.createdAt,
    this.metadata = RecipeMetadata.empty,
    this.ownerId,
    this.visibility = RecipeVisibility.private,
    this.publishedAt,
  });

  final String id;
  final String? ownerId;

  /// Standart ürün adı veya kullanıcı serbest metni ("Trabzon Ekmeği").
  /// Supabase'de `product_name` sütununa gider.
  final String productName;

  /// Otorite kaynak — gerçek miktarlar (kg).
  final RecipeQuantities quantities;

  /// `RecipeCalculator.calculateFromQuantities` çıktısı.
  /// Görüntü için kullanılır.
  final RecipeResult result;

  final RecipeMetadata metadata;
  final DateTime createdAt;

  final RecipeVisibility visibility;
  final DateTime? publishedAt;

  bool get isPublic => visibility.isPublic;

  /// Listede gösterilecek başlık.
  String get displayTitle {
    final title = metadata.title?.trim();
    if (title != null && title.isNotEmpty) return title;
    final product = productName.trim();
    if (product.isNotEmpty) return product;
    return 'Genel reçete';
  }

  /// Kart alt satırı: ürün etiketi.
  String get displaySubtitle {
    final title = metadata.title?.trim();
    if (title == null || title.isEmpty) return '';
    return productName.trim();
  }

  Recipe copyWith({
    String? id,
    String? ownerId,
    String? productName,
    RecipeQuantities? quantities,
    RecipeResult? result,
    RecipeMetadata? metadata,
    DateTime? createdAt,
    RecipeVisibility? visibility,
    DateTime? publishedAt,
  }) {
    return Recipe(
      id: id ?? this.id,
      ownerId: ownerId ?? this.ownerId,
      productName: productName ?? this.productName,
      quantities: quantities ?? this.quantities,
      result: result ?? this.result,
      metadata: metadata ?? this.metadata,
      createdAt: createdAt ?? this.createdAt,
      visibility: visibility ?? this.visibility,
      publishedAt: publishedAt ?? this.publishedAt,
    );
  }
}
