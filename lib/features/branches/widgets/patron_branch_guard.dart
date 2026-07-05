import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../profile/models/bakery_profile.dart';
import '../../profile/providers/profile_provider.dart';
import '../screens/my_branch_screen.dart';

/// Şube YÖNETİMİ ekranları (ana ekran, şube oluştur/detay, personel davet)
/// için rol guard'ı — PatronDriverGuard kalıbının şube karşılığı.
///
/// **FAIL-CLOSED:** Yönetim yüzeyi YALNIZ accountType kesin olarak
/// `commercial` ise gösterilir. Profil null/yüklenmedi/individual/wholesaler
/// → güvenli varsayılan olarak bireysel "Şube İşlerim" yüzeyine düşülür
/// (aktif üyelik yoksa o da sade boş durum gösterir; hiçbir yönetim aracı
/// render edilmez). Deep-link ile yönetime sızılamaz; asıl sınır RLS'tedir.
class PatronBranchGuard extends ConsumerWidget {
  const PatronBranchGuard({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final accountType = ref.watch(
      profileControllerProvider.select((p) => p?.accountType),
    );
    if (accountType == AccountType.commercial) {
      return child;
    }
    return const MyBranchScreen();
  }
}
