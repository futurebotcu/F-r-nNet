// V1.4 P1.7 — 4 dealer form save hata yönetimi regression.
//
// Risk register kanıtı: P1.7 — dealer_delivery/payment/return/adjustment
// form_screen.dart save handler'ları try/catch'siz idi; PostgrestException
// veya network hatası uncaught async error olarak düşüyor, kullanıcı
// sessizce kalıyordu.
//
// Bu test her 4 form için:
//   - Repo `addTransaction` throws → Türkçe hata snackbar görünür
//   - Form AÇIK kalır (Navigator.pop çağrılmaz)
//   - Kullanıcının girdiği değerler korunur

import 'package:firin_defter/core/constants/app_strings.dart';
import 'package:firin_defter/features/dealers/models/dealer_transaction.dart';
import 'package:firin_defter/features/dealers/providers/dealer_providers.dart';
import 'package:firin_defter/features/dealers/repositories/local_dealer_repository.dart';
import 'package:firin_defter/features/dealers/screens/dealer_adjustment_form_screen.dart';
import 'package:firin_defter/features/dealers/screens/dealer_delivery_form_screen.dart';
import 'package:firin_defter/features/dealers/screens/dealer_payment_form_screen.dart';
import 'package:firin_defter/features/dealers/screens/dealer_return_form_screen.dart';
import 'package:firin_defter/features/profile/models/bakery_profile.dart';
import 'package:firin_defter/features/profile/providers/profile_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _ThrowingDealerRepository extends LocalDealerRepository {
  _ThrowingDealerRepository() : super(seed: false);

  int addTransactionCalls = 0;

  @override
  Future<void> addTransaction(DealerTransaction tx) {
    addTransactionCalls++;
    return Future<void>.error(Exception('network boom (addTransaction)'));
  }
}

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

Widget _wrap(LocalDealerRepository repo, Widget screen) {
  return ProviderScope(
    overrides: [
      dealerRepositoryProvider.overrideWithValue(repo),
      profileControllerProvider.overrideWith(
        (ref) => _SeededProfileController(ref, _realProfile),
      ),
    ],
    child: MaterialApp(home: screen),
  );
}

Future<void> _tapSave(WidgetTester tester) async {
  await tester.tap(find.text('Kaydet'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'P1.7 Delivery — addTransaction throws → '
    'Türkçe hata snackbar; form açık kalır',
    (tester) async {
      final repo = _ThrowingDealerRepository();
      await tester.pumpWidget(
        _wrap(repo, const DealerDeliveryFormScreen(dealerId: 'd_test')),
      );
      await tester.pumpAndSettle();

      // Ürün seç ("Ekmek" chip).
      await tester.tap(find.text('Ekmek'));
      await tester.pumpAndSettle();

      // Miktar + birim fiyat doldur (delivery form'da 2 AppNumberField var,
      // 3. TextField not). first/at(0) = qty, at(1) = unit price.
      await tester.enterText(find.byType(TextField).at(0), '10');
      await tester.enterText(find.byType(TextField).at(1), '5');
      await tester.pump();

      await _tapSave(tester);

      expect(repo.addTransactionCalls, 1);
      expect(
        find.text(AppStrings.dealerDeliverySaveError),
        findsOneWidget,
        reason: 'Delivery save fırlattığında Türkçe hata gösterilmeli.',
      );

      // Form AÇIK kalır — başarı snackbar'ı gözükmemeli.
      expect(
        find.textContaining(AppStrings.dealerSaveSnackDelivery),
        findsNothing,
        reason: 'Hata yolunda success snackbar gösterilmemeli.',
      );
      // Form input "10" hâlâ görünür (Navigator.pop yapılmadı).
      expect(find.text('10'), findsOneWidget);
    },
  );

  testWidgets(
    'P1.7 Payment — addTransaction throws → '
    'Türkçe hata snackbar; form açık kalır',
    (tester) async {
      final repo = _ThrowingDealerRepository();
      await tester.pumpWidget(
        _wrap(repo, const DealerPaymentFormScreen(dealerId: 'd_test')),
      );
      await tester.pumpAndSettle();

      // Tutar doldur (payment form: 1 AppNumberField + 1 not TextField).
      await tester.enterText(find.byType(TextField).at(0), '100');
      await tester.pump();

      await _tapSave(tester);

      expect(repo.addTransactionCalls, 1);
      expect(
        find.text(AppStrings.dealerPaymentSaveError),
        findsOneWidget,
        reason: 'Payment save fırlattığında Türkçe hata gösterilmeli.',
      );
      expect(
        find.textContaining(AppStrings.dealerSaveSnackPayment),
        findsNothing,
      );
      expect(find.text('100'), findsOneWidget);
    },
  );

  testWidgets(
    'P1.7 Return — addTransaction throws → '
    'Türkçe hata snackbar; form açık kalır',
    (tester) async {
      final repo = _ThrowingDealerRepository();
      await tester.pumpWidget(
        _wrap(repo, const DealerReturnFormScreen(dealerId: 'd_test')),
      );
      await tester.pumpAndSettle();

      // Ürün seç.
      await tester.tap(find.text('Ekmek'));
      await tester.pumpAndSettle();

      // Miktar + birim fiyat.
      await tester.enterText(find.byType(TextField).at(0), '5');
      await tester.enterText(find.byType(TextField).at(1), '3');
      await tester.pump();

      await _tapSave(tester);

      expect(repo.addTransactionCalls, 1);
      expect(
        find.text(AppStrings.dealerReturnSaveError),
        findsOneWidget,
        reason: 'Return save fırlattığında Türkçe hata gösterilmeli.',
      );
      expect(
        find.textContaining(AppStrings.dealerSaveSnackReturn),
        findsNothing,
      );
      expect(find.text('5'), findsOneWidget);
    },
  );

  testWidgets(
    'P1.7 Adjustment — addTransaction throws → '
    'Türkçe hata snackbar; form açık kalır',
    (tester) async {
      final repo = _ThrowingDealerRepository();
      await tester.pumpWidget(
        _wrap(repo, const DealerAdjustmentFormScreen(dealerId: 'd_test')),
      );
      await tester.pumpAndSettle();

      // Tutar + not (note zorunlu).
      await tester.enterText(find.byType(TextField).at(0), '50');
      await tester.enterText(find.byType(TextField).at(1), 'Eski hesap düzeltme');
      await tester.pump();

      await _tapSave(tester);

      expect(repo.addTransactionCalls, 1);
      expect(
        find.text(AppStrings.dealerAdjustmentSaveError),
        findsOneWidget,
        reason: 'Adjustment save fırlattığında Türkçe hata gösterilmeli.',
      );
      expect(
        find.textContaining(AppStrings.dealerSaveSnackAdjustment),
        findsNothing,
      );
      // Not metni korunmuş.
      expect(find.text('Eski hesap düzeltme'), findsOneWidget);
    },
  );

  testWidgets(
    'P1.7 regression — Payment success path mevcut UX\'i korur (smoke)',
    (tester) async {
      final repo = LocalDealerRepository(seed: false);
      await tester.pumpWidget(
        _wrap(repo, const DealerPaymentFormScreen(dealerId: 'd_test')),
      );
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField).at(0), '100');
      await tester.pump();
      await tester.tap(find.text('Kaydet'));
      // pop sonrası MaterialApp tek route kaldığı için patlama vermesin diye
      // pumpAndSettle yerine kısa pump.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Hata snackbar'ı görünmemeli (success path break etmedi).
      expect(find.text(AppStrings.dealerPaymentSaveError), findsNothing);
    },
  );
}
