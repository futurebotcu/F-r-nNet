// V1.4 P1.4 — SplashScreen guest+session mutual-exclusion guard regression.
//
// Risk register kanıtı: P1.4 — Splash route decision'da `user != null &&
// isGuest` kontrolü yoktu. Ultra-slow cihazda OAuth callback + guest
// storage write race olursa kullanıcı authenticated ama guestMode=true
// durumunda kalabiliyordu → /feed'e guest mode'da düşer (tutarsız UX).
//
// Patch: `_route()` içinde user fetch sonrası + user == null branch'i
// ÖNCESİ defensive guard ekledi:
//
//   if (user != null && guest) {
//     await ref.read(guestModeProvider.notifier).setGuest(false);
//     if (!mounted) return;
//   }
//
// Bu test source-level audit pattern'iyle (account_deletion_p0_test.dart
// ile aynı) guard'ın doğru konumda + doğru çağrı ile var olduğunu doğrular.
// Tam widget pump testi 5+ provider override gerektiriyor (currentAuthUser,
// profile repo, guest mode bootstrap, ...) — source assertion regresyonu
// minimum-maliyetle kilitler.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('SplashScreen P1.4 mutual-exclusion guard (source)', () {
    late String src;
    setUpAll(() {
      src = File('lib/features/onboarding/screens/splash_screen.dart')
          .readAsStringSync();
    });

    test('guestModeProvider import edilmiş', () {
      expect(
        src.contains("import '../../auth/providers/guest_mode_provider.dart';"),
        isTrue,
        reason: 'setGuest(false) çağrısı için guestModeProvider import gerekir',
      );
    });

    test('P1.4 guard bloğu mevcut (user != null && guest)', () {
      // Defensive guard condition'ı arıyoruz. Boşluk farklarına tolerant
      // olmak için iki ayrı substring kontrolü yapalım.
      final hasGuardCondition = src.contains('user != null && guest');
      expect(hasGuardCondition, isTrue,
          reason: 'Guard condition `user != null && guest` mevcut olmalı');
      // setGuest(false) guard içinde olmalı:
      expect(
        src.contains('setGuest(false)'),
        isTrue,
        reason: 'Guard içinde guestModeProvider.notifier.setGuest(false) çağrısı olmalı',
      );
    });

    test('guard user fetch SONRASI ve user==null branch ÖNCESİ', () {
      final idxUserFetch =
          src.indexOf('final user = ref.read(currentAuthUserProvider);');
      final idxGuardCond = src.indexOf('user != null && guest');
      final idxSetGuest = src.indexOf('setGuest(false)', idxGuardCond);
      // `if (user == null) {` user==null branch'inin başlangıcı; guard'dan
      // SONRA gelmeli.
      final idxUserNullBranch = src.indexOf('if (user == null)', idxGuardCond);

      expect(idxUserFetch, greaterThan(-1),
          reason: 'currentAuthUserProvider okuma satırı olmalı');
      expect(idxGuardCond, greaterThan(idxUserFetch),
          reason: 'Guard condition user fetch sonrası gelmeli');
      expect(idxSetGuest, greaterThan(idxGuardCond),
          reason: 'setGuest(false) guard condition içinde olmalı');
      expect(idxUserNullBranch, greaterThan(idxSetGuest),
          reason: 'user == null branch guard\'dan sonra gelmeli');
    });

    test('guard içinde mounted check var (race-safe)', () {
      // setGuest(false) await'inden sonra `if (!mounted) return;` olmalı
      // ki widget unmount olduysa devamı çalışmasın.
      final idxSetGuest = src.indexOf('setGuest(false)');
      // Guard bloğunun sonuna kadarki ilk mounted check:
      final idxMountedAfter =
          src.indexOf('if (!mounted) return;', idxSetGuest);
      expect(idxMountedAfter, greaterThan(idxSetGuest),
          reason: 'Guard içinde setGuest sonrası mounted check olmalı');
      // Mounted check, sonraki route decision'dan (user==null branch) ÖNCE
      // gelmeli — yani guard'ın içinde, dışarıda değil.
      final idxUserNullBranch =
          src.indexOf('if (user == null)', idxSetGuest);
      expect(idxMountedAfter, lessThan(idxUserNullBranch),
          reason: 'mounted check user==null branch öncesi, yani guard içinde olmalı');
    });

    test('mevcut 6 route senaryosu yorumu korunmuş', () {
      // Patch davranış kontratını bozmadı — 6 senaryo dokümante kalmalı.
      expect(src.contains('6 olası rota'), isTrue);
    });
  });
}
