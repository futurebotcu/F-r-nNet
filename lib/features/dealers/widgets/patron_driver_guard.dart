import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../profile/models/bakery_profile.dart';
import '../../profile/providers/profile_provider.dart';
import '../screens/driver_home_screen.dart';

/// Patron şoför YÖNETİMİ ekranları (Şoförler listesi, Genel Hesap, Şoför Daveti,
/// şoför detay, bayi atama) için rol guard'ı (deep-link hardening).
///
/// Bireysel kullanıcı = ŞOFÖR; patron yönetimine UI'da girişi yok. Doğrudan
/// deep-link (`/dealers/drivers...`) ile bu ekranlara ulaşmaya çalışırsa patron
/// yönetimi AÇILMAZ → güvenli şekilde [DriverHomeScreen]'e ("Bana Atanan
/// Bayiler" / davet kartı / boş durum) düşer. Ticari (commercial) ve toptancı
/// (wholesaler) patron/owner'dır → [child] aynen gösterilir.
///
/// **FAIL-CLOSED (FN-AUDIT-002):** Patron yüzeyi YALNIZCA accountType kesin
/// olarak `commercial` veya `wholesaler` ise gösterilir. Profil henüz
/// yüklenmediyse (`null`), yükleme hata aldıysa veya `individual` ise → güvenli
/// varsayılan olarak şoför görünümüne düşülür. Böylece geçici profil hatası bir
/// bireysel/şoför kullanıcıyı patron yönetim ekranına düşürmez (önceki davranış
/// `null → child` ile fail-OPEN idi).
class PatronDriverGuard extends ConsumerWidget {
  const PatronDriverGuard({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final accountType = ref.watch(
      profileControllerProvider.select((p) => p?.accountType),
    );
    // Yalnız kesin patron rolleri child'ı (patron yönetimi) görür.
    if (accountType == AccountType.commercial ||
        accountType == AccountType.wholesaler) {
      return child;
    }
    // null / individual / bilinmeyen → güvenli varsayılan: şoför görünümü.
    return const DriverHomeScreen();
  }
}
