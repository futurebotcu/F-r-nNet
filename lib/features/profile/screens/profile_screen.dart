// FırınNet V1 Unified Profile M2 — /profile route redirector.
//
// Eski ProfileScreen public-benzeri görünüm (header + açık reçeteler +
// settings) Unified Profile M2 ile **kaldırıldı**. Dışarıdan görülen tek
// public profil `/u/:userId` → SocialProfilePage.
//
// `/profile` route geriye dönük uyumluluk için açık tutuldu; bu ekran
// kendi user id'mize otomatik yönlendirir. Guest ise /auth'a düşer.
//
// Profil ayarları / hesap silme / yasal metinler → /settings.
// Bireysel (usta) bilgi formu → /worker/profile.
// Bakery / Üretim panelleri → /panel/bakery (commercial dashboard).

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/app_router.dart';
import '../../../app/theme/app_colors.dart';
import '../../auth/providers/auth_providers.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  bool _redirected = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _redirectIfReady());
  }

  void _redirectIfReady() {
    if (_redirected) return;
    final user = ref.read(currentAuthUserProvider);
    if (!mounted) return;
    // pushReplacement (go DEĞİL): bu ekran bir redirector; `/profile` genelde
    // Panel kartından / Feed avatarından PUSH ile açılır. `context.go` tüm
    // back-stack'i sıfırlardı → hedef ekranda geri tuşu uygulamadan çıkarırdı.
    // pushReplacement yalnız bu redirector sayfasını değiştirir; altındaki
    // shell/Panel korunur → AppBar + sistem geri tuşu önceki ekrana döner.
    if (user == null) {
      _redirected = true;
      context.pushReplacement(AppRoutes.authEntry);
      return;
    }
    _redirected = true;
    context.pushReplacement('${AppRoutes.userPublicProfile}/${user.id}');
  }

  @override
  Widget build(BuildContext context) {
    // Auth state stream'i geç gelebilir; user resolve olunca
    // post-frame'de redirect tetiklenecek.
    ref.listen<dynamic>(currentAuthUserProvider, (_, __) {
      _redirectIfReady();
    });
    return const Scaffold(
      backgroundColor: AppColors.background,
      body: Center(child: CircularProgressIndicator()),
    );
  }
}
