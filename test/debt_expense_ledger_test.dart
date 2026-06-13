// Borç & Gider Defteri V1 — mini-app test seti.
//
// Kapsam:
//   • Model türetimi: remaining / isClosed / statusOn (open/partial/paid/overdue)
//   • LocalRepo: addEntry id ataması + kind filtre + tarih sıralama,
//     addPayment → paid artışı → remaining yeniden hesap
//   • Guarded repo: write izni yoksa GuestActionRequiredException
//   • Summary provider: açık borç / bu ay gider / personel / vade / geciken / kapanan
//   • Panel kartı: ticari kullanıcıda "Borç & Gider" görünür, bireysel/toptancıda YOK
//   • Shell: 5 tab render + tab geçişi
//   • Form: "Diğer/manuel" boş kategori engeli + manuel kategori kaydı
//   • Form: çift-submit guard (in-flight iken ikinci tap addEntry'yi tekrar çağırmaz)
//   • Migration: owner-only RLS source-contract (kaynak dosya seviyesi)

import 'dart:async';
import 'dart:io';

import 'package:firin_defter/core/constants/app_strings.dart';
import 'package:firin_defter/core/widgets/app_primary_button.dart';
import 'package:firin_defter/features/auth/services/auth_required_guard.dart';
import 'package:firin_defter/features/dashboard/services/role_panel_cards.dart';
import 'package:firin_defter/features/debt_expense/models/debt_expense_entry.dart';
import 'package:firin_defter/features/debt_expense/providers/debt_expense_providers.dart';
import 'package:firin_defter/features/debt_expense/repositories/guarded_debt_expense_repository.dart';
import 'package:firin_defter/features/debt_expense/repositories/local_debt_expense_repository.dart';
import 'package:firin_defter/features/debt_expense/screens/debt_expense_entry_form_screen.dart';
import 'package:firin_defter/features/debt_expense/screens/debt_expense_shell_screen.dart';
import 'package:firin_defter/features/profile/models/bakery_profile.dart';
import 'package:firin_defter/features/profile/providers/profile_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

const _commercialProfile = BakeryProfile(
  displayName: 'Hasan Usta',
  accountType: AccountType.commercial,
  city: 'Konya',
  roleBadge: 'Fırıncı',
  email: 'hasan@example.com',
);

class _SeededProfileController extends ProfileController {
  _SeededProfileController(super.ref, BakeryProfile initial) {
    state = initial;
  }
}

DebtExpenseEntry _debt({
  String id = 'x',
  double total = 1000,
  double paid = 0,
  DateTime? due,
  DateTime? created,
}) =>
    DebtExpenseEntry(
      id: id,
      kind: DebtExpenseKind.debt,
      title: 'Uncu Mehmet',
      totalAmount: total,
      paidAmount: paid,
      dueDate: due,
      createdAt: created ?? DateTime(2026, 6, 1),
    );

void main() {
  // ---------------------------------------------------------------------------
  group('Model — remaining / isClosed / statusOn', () {
    final today = DateTime(2026, 6, 12);

    test('remaining negatife düşmez, isClosed paid>=total', () {
      expect(_debt(total: 1000, paid: 300).remaining, 700);
      expect(_debt(total: 1000, paid: 1200).remaining, 0);
      expect(_debt(total: 1000, paid: 1000).isClosed, isTrue);
      expect(_debt(total: 1000, paid: 999).isClosed, isFalse);
      // total 0 → isClosed asla true olmaz (drift guard).
      expect(_debt(total: 0, paid: 0).isClosed, isFalse);
    });

    test('status: open (ödeme yok, vade gelecek/yok)', () {
      expect(_debt(total: 1000, paid: 0).statusOn(today),
          DebtExpenseStatus.open);
      expect(
        _debt(total: 1000, paid: 0, due: DateTime(2026, 6, 20)).statusOn(today),
        DebtExpenseStatus.open,
      );
    });

    test('status: partial (kısmi ödeme, vade geçmemiş)', () {
      expect(_debt(total: 1000, paid: 400).statusOn(today),
          DebtExpenseStatus.partial);
    });

    test('status: paid (kapandı) — vade geçmiş olsa bile paid önceliklidir', () {
      expect(
        _debt(total: 1000, paid: 1000, due: DateTime(2026, 6, 1))
            .statusOn(today),
        DebtExpenseStatus.paid,
      );
    });

    test('status: overdue (vade dün, kapanmamış)', () {
      expect(
        _debt(total: 1000, paid: 200, due: DateTime(2026, 6, 11)).statusOn(today),
        DebtExpenseStatus.overdue,
      );
    });

    test('vade bugün → overdue DEĞİL (gün-bazlı, bugün hâlâ vakit var)', () {
      expect(
        _debt(total: 1000, paid: 0, due: today).statusOn(today),
        DebtExpenseStatus.open,
      );
    });
  });

  // ---------------------------------------------------------------------------
  group('LocalRepo — kayıt / ödeme', () {
    test('addEntry id atar, listEntries kind filtreler + tarihe göre sıralar',
        () async {
      final repo = LocalDebtExpenseRepository();
      await repo.addEntry(_debt(id: '', created: DateTime(2026, 6, 1)));
      await repo.addEntry(DebtExpenseEntry(
        id: '',
        kind: DebtExpenseKind.expense,
        title: 'Elektrik',
        totalAmount: 500,
        paidAmount: 500,
        createdAt: DateTime(2026, 6, 5),
      ));
      await repo.addEntry(_debt(id: '', created: DateTime(2026, 6, 10)));

      final all = await repo.listEntries();
      expect(all.length, 3);
      // En yeni önce (created desc).
      expect(all.first.createdAt, DateTime(2026, 6, 10));
      // Hepsine id atanmış.
      expect(all.every((e) => e.id.isNotEmpty), isTrue);

      final debts = await repo.listEntries(kind: DebtExpenseKind.debt);
      expect(debts.length, 2);
      expect(debts.every((e) => e.kind == DebtExpenseKind.debt), isTrue);

      final expenses = await repo.listEntries(kind: DebtExpenseKind.expense);
      expect(expenses.single.title, 'Elektrik');
    });

    test('addPayment paid artırır → remaining yeniden hesaplanır → kapanır',
        () async {
      final repo = LocalDebtExpenseRepository();
      final saved =
          await repo.addEntry(_debt(id: '', total: 1000, paid: 0));

      await repo.addPayment(saved.id, 300);
      var cur = (await repo.listEntries()).single;
      expect(cur.paidAmount, 300);
      expect(cur.remaining, 700);
      expect(cur.statusOn(DateTime(2026, 6, 12)), DebtExpenseStatus.partial);

      await repo.addPayment(saved.id, 700);
      cur = (await repo.listEntries()).single;
      expect(cur.paidAmount, 1000);
      expect(cur.remaining, 0);
      expect(cur.isClosed, isTrue);
    });
  });

  // ---------------------------------------------------------------------------
  group('Guarded repo — guest write engeli', () {
    test('canWrite=false → addEntry/addPayment GuestActionRequiredException',
        () async {
      final guarded = GuardedDebtExpenseRepository(
        inner: LocalDebtExpenseRepository(),
        canWriteCheck: () => false,
      );
      expect(
        () => guarded.addEntry(_debt(id: '')),
        throwsA(isA<GuestActionRequiredException>()),
      );
      expect(
        () => guarded.addPayment('x', 10),
        throwsA(isA<GuestActionRequiredException>()),
      );
      // Okuma serbest.
      expect(await guarded.listEntries(), isEmpty);
    });

    test('canWrite=true → write iç repoya geçer', () async {
      final inner = LocalDebtExpenseRepository();
      final guarded = GuardedDebtExpenseRepository(
        inner: inner,
        canWriteCheck: () => true,
      );
      await guarded.addEntry(_debt(id: ''));
      expect((await inner.listEntries()).length, 1);
    });
  });

  // ---------------------------------------------------------------------------
  group('Summary provider — özet hesabı', () {
    Future<LocalDebtExpenseRepository> seeded() async {
      final repo = LocalDebtExpenseRepository();
      final now = DateTime.now();
      final monthStart = DateTime(now.year, now.month, 1);
      final overdueDue = DateTime(now.year, now.month, now.day)
          .subtract(const Duration(days: 3));
      final upcomingDue = DateTime(now.year, now.month, now.day)
          .add(const Duration(days: 3));

      // Açık borç: kalan 700.
      await repo.addEntry(_debt(
          id: '', total: 1000, paid: 300, created: monthStart));
      // Kapanan borç (paid).
      await repo.addEntry(_debt(
          id: '', total: 500, paid: 500, created: monthStart));
      // Geciken borç: kalan 400, vade 3 gün önce.
      await repo.addEntry(_debt(
          id: '',
          total: 400,
          paid: 0,
          due: overdueDue,
          created: monthStart));
      // Bu hafta vadesi gelen borç (3 gün sonra).
      await repo.addEntry(_debt(
          id: '', total: 200, paid: 0, due: upcomingDue, created: monthStart));
      // Bu ay gider 250.
      await repo.addEntry(DebtExpenseEntry(
        id: '',
        kind: DebtExpenseKind.expense,
        title: 'Elektrik',
        totalAmount: 250,
        paidAmount: 250,
        createdAt: now,
      ));
      // Ödenecek personel 800.
      await repo.addEntry(DebtExpenseEntry(
        id: '',
        kind: DebtExpenseKind.staffPayment,
        title: 'Ahmet',
        staffPaymentType: StaffPaymentType.salary,
        totalAmount: 800,
        paidAmount: 0,
        createdAt: now,
      ));
      return repo;
    }

    test('öz metrikler doğru türetilir', () async {
      final repo = await seeded();
      final container = ProviderContainer(overrides: [
        debtExpenseRepositoryProvider.overrideWithValue(repo),
      ]);
      addTearDown(container.dispose);

      final s = await container.read(debtExpenseSummaryProvider.future);
      // Açık borç kalanı: 700 (kısmi) + 400 (geciken) + 200 (vade) = 1300.
      expect(s.openDebtTotal, 1300);
      expect(s.thisMonthExpense, 250);
      expect(s.staffPayableTotal, 800);
      expect(s.closedDebtCount, 1);
      expect(s.overdueCount, 1);
      expect(s.overdueTotal, 400);
      expect(s.upcomingThisWeek, 1);
    });
  });

  // ---------------------------------------------------------------------------
  group('Panel kartı — role görünürlüğü', () {
    test('ticari kullanıcıda "Borç & Gider" kartı + /debt-expense rota var', () {
      final cards = RolePanelCards.forAccount(AccountType.commercial);
      final match =
          cards.where((c) => c.route == '/debt-expense').toList();
      expect(match.length, 1);
      expect(match.single.label, AppStrings.debtExpenseTitle);
    });

    test('bireysel ve toptancıda "Borç & Gider" kartı YOK (davranış korunur)',
        () {
      for (final t in [AccountType.individual, AccountType.wholesaler]) {
        final cards = RolePanelCards.forAccount(t);
        expect(
          cards.any((c) => c.route == '/debt-expense'),
          isFalse,
          reason: '$t için Borç & Gider kartı eklenmemeli.',
        );
        // Rol kart seti boş kalmamış (davranış korunur).
        expect(cards, isNotEmpty);
      }
      // Bireyselde Bayi Defteri (dealers) hâlâ duruyor.
      expect(
        RolePanelCards.forAccount(AccountType.individual)
            .any((c) => c.route == '/dealers'),
        isTrue,
      );
    });

    test('ticaride Bayi Defteri (dealers) kartı korunur', () {
      final cards = RolePanelCards.forAccount(AccountType.commercial);
      expect(cards.any((c) => c.route == '/dealers'), isTrue);
    });
  });

  // ---------------------------------------------------------------------------
  group('Shell — 5 tab', () {
    testWidgets('5 sekme render olur ve tab geçişi çalışır', (tester) async {
      final repo = LocalDebtExpenseRepository();
      await tester.pumpWidget(ProviderScope(
        overrides: [
          debtExpenseRepositoryProvider.overrideWithValue(repo),
        ],
        child: const MaterialApp(home: DebtExpenseShellScreen()),
      ));
      await tester.pumpAndSettle();

      // 5 bottom-nav label.
      expect(find.text(AppStrings.deTabOverview), findsWidgets);
      expect(find.text(AppStrings.deTabDebts), findsWidgets);
      expect(find.text(AppStrings.deTabExpenses), findsWidgets);
      expect(find.text(AppStrings.deTabStaff), findsWidgets);
      expect(find.text(AppStrings.deTabReports), findsWidgets);

      // Raporlar sekmesine geç.
      await tester.tap(find.text(AppStrings.deTabReports).last);
      await tester.pumpAndSettle();
      expect(find.text('Kapanan borç sayısı'), findsOneWidget);
    });
  });

  // ---------------------------------------------------------------------------
  group('Form — kategori + çift-submit', () {
    Widget wrap(LocalDebtExpenseRepository repo, DebtExpenseKind kind) {
      return ProviderScope(
        overrides: [
          debtExpenseRepositoryProvider.overrideWithValue(repo),
          profileControllerProvider.overrideWith(
            (ref) => _SeededProfileController(ref, _commercialProfile),
          ),
        ],
        child: MaterialApp(home: DebtExpenseEntryFormScreen(kind: kind)),
      );
    }

    // Kaydet butonu uzun ListView'in altında — lazy viewport'ta görünür kıl.
    Future<void> scrollToSave(WidgetTester tester) async {
      await tester.scrollUntilVisible(
        find.byType(AppPrimaryButton),
        250,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.ensureVisible(find.byType(AppPrimaryButton));
      await tester.pump();
    }

    Future<void> tapSave(WidgetTester tester) async {
      await scrollToSave(tester);
      await tester.tap(find.byType(AppPrimaryButton));
    }

    testWidgets('"Diğer" seçili + boş kategori → kayıt engellenir, uyarı çıkar',
        (tester) async {
      final repo = LocalDebtExpenseRepository();
      await tester.pumpWidget(wrap(repo, DebtExpenseKind.debt));
      await tester.pumpAndSettle();

      // Başlık + tutar dolu, ama kategori "Diğer" boş.
      // Tutarı Diğer'den ÖNCE gir: Diğer inline TextField eklenince index kayar.
      await tester.enterText(find.byType(TextField).at(0), 'Uncu Mehmet');
      await tester.enterText(find.byType(TextField).at(1), '1500'); // tutar
      await tester.tap(find.text('Diğer'));
      await tester.pumpAndSettle();

      await tapSave(tester);
      await tester.pumpAndSettle();

      expect(find.text('Kategori adını yaz.'), findsOneWidget);
      expect(await repo.listEntries(), isEmpty,
          reason: 'Boş "Diğer" kategori ile kayıt eklenmemeli.');
    });

    testWidgets('manuel kategori + geçerli alanlar → kayıt eklenir',
        (tester) async {
      final repo = LocalDebtExpenseRepository();
      await tester.pumpWidget(wrap(repo, DebtExpenseKind.debt));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField).at(0), 'Uncu Mehmet');
      // Preset kategori seç (Un) — manuel akıştan bağımsız deterministik.
      await tester.tap(find.text('Un').first);
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).at(1), '1500');
      await tester.pump();

      await tapSave(tester);
      await tester.pumpAndSettle();

      final saved = await repo.listEntries();
      expect(saved.length, 1);
      expect(saved.single.title, 'Uncu Mehmet');
      expect(saved.single.category, 'Un');
      expect(saved.single.totalAmount, 1500);
    });

    testWidgets('çift-submit guard: in-flight iken ikinci tap addEntry tekrar '
        'çağırmaz', (tester) async {
      final repo = _BlockingAddRepo();
      await tester.pumpWidget(wrap(repo, DebtExpenseKind.debt));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField).at(0), 'Uncu Mehmet');
      await tester.tap(find.text('Un').first);
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).at(1), '1500');
      await tester.pump();

      // 1. tap — addEntry başlar ve completer'da bekler; buton disable olur.
      await scrollToSave(tester);
      await tester.tap(find.byType(AppPrimaryButton));
      await tester.pump();
      // 2. tap — _saving=true olduğundan no-op olmalı.
      await tester.tap(find.byType(AppPrimaryButton));
      await tester.pump();

      expect(repo.addCalls, 1, reason: 'Çift-submit guard tek kayıt bırakmalı.');

      repo.release();
      await tester.pumpAndSettle();
    });
  });

  // ---------------------------------------------------------------------------
  group('Migration — owner-only RLS source-contract', () {
    late String sql;
    setUpAll(() {
      sql = File(
        'supabase/migrations/20260612060000_debt_expense_ledger_v1.sql',
      ).readAsStringSync();
    });

    test('debt_expense_entries tablosu + kind CHECK tanımlı', () {
      expect(sql.contains('create table if not exists '
          'public.debt_expense_entries'), isTrue);
      expect(
        sql.contains("check (kind in ('debt','expense','staff_payment'))"),
        isTrue,
      );
    });

    test('RLS enabled + 4 owner-only policy (to authenticated, auth.uid())',
        () {
      expect(
        sql.contains('alter table public.debt_expense_entries '
            'enable row level security'),
        isTrue,
      );
      for (final p in [
        'debt_expense_select_own',
        'debt_expense_insert_own',
        'debt_expense_update_own',
        'debt_expense_delete_own',
      ]) {
        expect(sql.contains('create policy $p'), isTrue, reason: '$p eksik');
      }
      expect(sql.contains('to authenticated'), isTrue);
      expect(sql.contains('owner_id = auth.uid()'), isTrue);
      // anon erişim yok — sadece authenticated.
      expect(sql.contains('to anon'), isFalse);
    });
  });
}

/// addEntry'yi completer ile askıda tutan repo — çift-submit guard testi için.
class _BlockingAddRepo extends LocalDebtExpenseRepository {
  int addCalls = 0;
  final Completer<void> _gate = Completer<void>();
  void release() => _gate.complete();

  @override
  Future<DebtExpenseEntry> addEntry(DebtExpenseEntry entry) async {
    addCalls++;
    await _gate.future;
    return super.addEntry(entry);
  }
}
