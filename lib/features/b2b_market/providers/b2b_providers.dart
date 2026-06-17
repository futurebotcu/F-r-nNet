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

/// B2B mock repository sağlayıcısı.
final b2bRepositoryProvider = Provider<B2bRepository>((ref) {
  return const LocalB2bRepository();
});

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
