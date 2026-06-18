// B2B Pazar — Riverpod provider'ları.
//
// Repository şimdilik LocalB2bRepository'ye sabit (mock); Supabase'e geçişte
// yalnız bu satır değişir, UI dokunulmaz.
//
// ROL ÇÖZÜMÜ (role resolution) — TEK NOKTA: [b2bRoleProvider].
// Pazar'a giren kullanıcının B2B görünümü (tedarikçi / alıcı) burada,
// profildeki AccountType'tan türetilir. AccountType DEĞİŞTİRİLMEZ, yalnız
// okunur (mevcut profil/auth/AccountType bozulmaz):
//   * AccountType.wholesaler  → tedarikçi B2B görünümü
//   * diğer tüm roller / profil yok → alıcı (fırıncı) B2B görünümü
// Kullanıcıya rol değiştirme UI'ı YOKTUR. Test/development için yalnız
// [b2bRoleOverrideProvider] üzerinden zorlanabilir (üretimde null).

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../profile/models/bakery_profile.dart';
import '../../profile/providers/profile_provider.dart';
import '../repositories/b2b_repository.dart';
import '../repositories/local_b2b_repository.dart';

/// B2B mock repository sağlayıcısı. In-memory mutable tek örnek (oturum
/// boyunca korunur); write'lar [b2bMarketControllerProvider] üzerinden yapılır.
final b2bRepositoryProvider = Provider<B2bRepository>((ref) {
  return LocalB2bRepository();
});

/// Mağaza yönetim write akışlarının tek giriş noktası + reaktif sinyal.
///
/// State bir revizyon sayacıdır: her write sonrası artar → ürün/kampanya/
/// mağaza gösteren tab'lar bu provider'ı izleyerek yeniden çizilir.
/// Backend/persist YOK (mock, in-memory).
final b2bMarketControllerProvider =
    NotifierProvider<B2bMarketController, int>(B2bMarketController.new);

class B2bMarketController extends Notifier<int> {
  @override
  int build() => 0;

  B2bRepository get _repo => ref.read(b2bRepositoryProvider);

  void addProduct({
    required String name,
    required String category,
    required String minOrder,
    required String deliveryRegion,
    String description = '',
    bool published = true,
  }) {
    _repo.addProduct(
      name: name,
      category: category,
      minOrder: minOrder,
      deliveryRegion: deliveryRegion,
      description: description,
      published: published,
    );
    state++;
  }

  void addCampaign({
    required String title,
    required String category,
    required String region,
    required String minPurchase,
    required String validUntil,
    String? linkedProduct,
    String description = '',
    bool published = true,
  }) {
    _repo.addCampaign(
      title: title,
      category: category,
      region: region,
      minPurchase: minPurchase,
      validUntil: validUntil,
      linkedProduct: linkedProduct,
      description: description,
      published: published,
    );
    state++;
  }

  void updateStore({
    required String name,
    required String description,
    required List<String> serviceRegions,
    required List<String> categories,
  }) {
    _repo.updateStore(
      name: name,
      description: description,
      serviceRegions: serviceRegions,
      categories: categories,
    );
    state++;
  }

  void updateProduct({
    required String id,
    required String name,
    required String category,
    required String minOrder,
    required String deliveryRegion,
    String description = '',
    bool published = true,
  }) {
    _repo.updateProduct(
      id: id,
      name: name,
      category: category,
      minOrder: minOrder,
      deliveryRegion: deliveryRegion,
      description: description,
      published: published,
    );
    state++;
  }

  void updateCampaign({
    required String id,
    required String title,
    required String category,
    required String region,
    required String minPurchase,
    required String validUntil,
    String? linkedProduct,
    String description = '',
    bool published = true,
  }) {
    _repo.updateCampaign(
      id: id,
      title: title,
      category: category,
      region: region,
      minPurchase: minPurchase,
      validUntil: validUntil,
      linkedProduct: linkedProduct,
      description: description,
      published: published,
    );
    state++;
  }

  void setProductPublished(String id, bool published) {
    _repo.setProductPublished(id, published);
    state++;
  }

  void setCampaignPublished(String id, bool published) {
    _repo.setCampaignPublished(id, published);
    state++;
  }
}

/// Pazar'a giren kullanıcının B2B görünüm rolü.
enum B2bRole { supplier, buyer }

extension B2bRoleX on B2bRole {
  /// Header alt metni — role özgü, sade (önizleme/demo metni YOK).
  String get headerSubtitle {
    switch (this) {
      case B2bRole.supplier:
        return 'B2B tedarik ağı';
      case B2bRole.buyer:
        return 'Fırının için ürün ve tedarikçi keşfi';
    }
  }
}

/// Yalnız test/development için rol zorlama. Üretimde `null` → rol
/// [b2bRoleProvider] içinde profilden çözülür. UI'da bu provider'ı
/// değiştiren hiçbir kontrol YOKTUR.
final b2bRoleOverrideProvider = StateProvider<B2bRole?>((ref) => null);

/// Tek role resolution noktası. Override varsa onu, yoksa profildeki
/// AccountType'tan türetilen rolü döner.
final b2bRoleProvider = Provider<B2bRole>((ref) {
  final override = ref.watch(b2bRoleOverrideProvider);
  if (override != null) return override;
  final account = ref.watch(
    profileControllerProvider.select((p) => p?.accountType),
  );
  return account == AccountType.wholesaler ? B2bRole.supplier : B2bRole.buyer;
});
