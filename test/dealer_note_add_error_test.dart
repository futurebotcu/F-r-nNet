// V1.4 P1.23 — DealerDetailScreen `NotesCard` hata yönetimi regression.
//
// 10/10 Risk Discovery (U-1) bulgusu: `_NotesCardState._add` içinde
// `repo.addNote(...)` çağrısı try/catch'siz idi. Başarısız olursa
// `_saving = true` set edilmiş hâlde kalıyor, kaydet butonu kalıcı
// disabled, kullanıcıya hata snackbar'ı gösterilmiyordu (P0.1 feed
// composer bug ile birebir aynı şekil).
//
// Bu test:
//   1) Hata yolunda → Türkçe snackbar, _saving=false, not metni input'ta
//      korunur, kaydet butonu yeniden basılabilir.
//   2) Başarı yolunda → not eklenir, input temizlenir (mevcut UX
//      regresyon olarak korunur).

import 'package:firin_defter/core/constants/app_strings.dart';
import 'package:firin_defter/features/dealers/providers/dealer_providers.dart';
import 'package:firin_defter/features/dealers/repositories/local_dealer_repository.dart';
import 'package:firin_defter/features/dealers/screens/dealer_detail_screen.dart';
import 'package:firin_defter/features/dealers/models/dealer_note.dart';
import 'package:firin_defter/features/profile/models/bakery_profile.dart';
import 'package:firin_defter/features/profile/providers/profile_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

/// addNote daima fırlatan stub. Diğer DealerRepository metodları
/// LocalDealerRepository üzerinden çalışır (NotesCard build sırasında
/// onlara değmiyor; ama parity için extends ile geliyor).
class _ThrowingDealerRepository extends LocalDealerRepository {
  _ThrowingDealerRepository() : super(seed: false);

  int addNoteCalls = 0;

  @override
  Future<void> addNote(DealerNote note) {
    addNoteCalls++;
    return Future<void>.error(Exception('network boom'));
  }
}

/// `profileControllerProvider` üzerinde seed profile ile başlayan stub.
/// AppConfig.supabaseEnabled test'te false; super constructor
/// authRepositoryProvider null görür ve _loadFor tetiklenmez; state'i
/// biz tohumlarız ki AuthRequiredGuard.canWriteWithRef true dönsün.
class _SeededProfileController extends ProfileController {
  _SeededProfileController(super.ref, BakeryProfile initial) {
    state = initial;
  }
}

const _realProfile = BakeryProfile(
  displayName: 'Hasan Usta',
  accountType: AccountType.commercial,
  city: 'Konya',
  roleBadge: 'Fırıncı',
  email: 'hasan@example.com',
);

Widget _wrap({
  required _NotesCardOverrides overrides,
  BakeryProfile profile = _realProfile,
}) {
  return ProviderScope(
    overrides: [
      dealerRepositoryProvider.overrideWithValue(overrides.repo),
      profileControllerProvider.overrideWith(
        (ref) => _SeededProfileController(ref, profile),
      ),
    ],
    child: MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: SizedBox(
            width: 360,
            child: NotesCard(
              dealerId: 'd_test',
              notes: const <DealerNote>[],
            ),
          ),
        ),
      ),
    ),
  );
}

class _NotesCardOverrides {
  _NotesCardOverrides({required this.repo});
  final LocalDealerRepository repo;
}

Future<void> _typeAndTap(WidgetTester tester, String text) async {
  await tester.enterText(find.byType(TextField), text);
  await tester.pump();
  await tester.tap(find.byType(FilledButton));
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(() async {
    // NotesCard.build içinde `DateFormat('d MMM yyyy', 'tr_TR')` çağrısı var.
    // Test ortamında locale verisi yüklenmediği için init etmek gerekiyor
    // (dealer_share_builder_test.dart ve dealer_pdf_builder_test.dart aynı
    // pattern'i kullanıyor).
    await initializeDateFormatting('tr_TR', null);
  });

  testWidgets(
    'NotesCard P1.23 — addNote throws → Türkçe hata snackbar, '
    '_saving=false, not metni korunur, kaydet butonu yeniden basılabilir',
    (tester) async {
      final repo = _ThrowingDealerRepository();
      await tester.pumpWidget(_wrap(overrides: _NotesCardOverrides(repo: repo)));

      const userText = 'Hatice Abla bu hafta peynirli pide istedi.';
      await _typeAndTap(tester, userText);

      // 1) Repo gerçekten çağrıldı (guard pre-check geçti).
      expect(repo.addNoteCalls, 1);

      // 2) Türkçe hata snackbar'ı görünür.
      expect(
        find.text(AppStrings.dealerNoteAddError),
        findsOneWidget,
        reason: 'addNote fırlattığında kullanıcıya Türkçe hata gösterilmeli.',
      );

      // 3) Not metni korunmuş (kullanıcı tek tıkla tekrar deneyebilsin).
      expect(find.text(userText), findsOneWidget);

      // 4) _saving=false → FilledButton.onPressed yeniden non-null.
      final btn = tester.widget<FilledButton>(find.byType(FilledButton));
      expect(
        btn.onPressed,
        isNotNull,
        reason: '_saving=true takılı kalsaydı buton disabled olurdu.',
      );

      // 5) Buton tekrar tıklanır — repo ikinci çağrıyı görmeli.
      await tester.tap(find.byType(FilledButton));
      await tester.pumpAndSettle();
      expect(repo.addNoteCalls, 2);
    },
  );

  testWidgets(
    'NotesCard regression — addNote başarılıysa input temizlenir, '
    'kaydet butonu yeniden basılabilir',
    (tester) async {
      final repo = LocalDealerRepository(seed: false);
      await tester.pumpWidget(_wrap(overrides: _NotesCardOverrides(repo: repo)));

      const userText = 'İade gelen 6 ekmek bugün yerine konacak.';
      await _typeAndTap(tester, userText);

      // Hata snackbar'ı gözükmemeli.
      expect(find.text(AppStrings.dealerNoteAddError), findsNothing);

      // Input temizlenmiş — kullanıcı metni artık görünmemeli.
      expect(find.text(userText), findsNothing);

      // _saving false: buton tekrar basılabilir.
      final btn = tester.widget<FilledButton>(find.byType(FilledButton));
      expect(btn.onPressed, isNotNull);
    },
  );
}
