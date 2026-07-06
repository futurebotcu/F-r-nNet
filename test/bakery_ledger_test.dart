import 'package:firin_defter/features/bakery_panel/models/bakery_day_book.dart';
import 'package:firin_defter/features/bakery_panel/models/daily_summary.dart';
import 'package:firin_defter/features/bakery_panel/models/ledger_range_report.dart';
import 'package:firin_defter/features/bakery_panel/models/production_entry.dart';
import 'package:firin_defter/features/bakery_panel/models/waste_entry.dart';
import 'package:firin_defter/features/bakery_panel/providers/bakery_providers.dart';
import 'package:firin_defter/features/bakery_panel/repositories/local_bakery_repository.dart';
import 'package:flutter_test/flutter_test.dart';

/// Fırın Defteri V1 — model/hesap + Local repo davranış testleri.
/// Local repo server (RPC/RLS) kurallarının aynasıdır; asıl güvenlik DB'de
/// canlı smoke ile doğrulanmıştır (14/14).
void main() {
  final today = DateTime.now();

  ProductionEntry prod(String product, int qty, {DateTime? at}) =>
      ProductionEntry(
        id: 'p-$product-$qty',
        product: product,
        quantity: qty,
        note: '',
        createdAt: at ?? today,
      );

  WasteEntry waste(
    String product,
    int qty, {
    double unitValue = 5,
    WasteReason reason = WasteReason.other,
    DateTime? at,
  }) => WasteEntry(
    id: 'w-$product-$qty',
    product: product,
    quantity: qty,
    unitValue: unitValue,
    note: '',
    createdAt: at ?? today,
    reason: reason,
  );

  group('fire sebebi (waste_type) eşlemesi', () {
    test('persistKey round-trip', () {
      for (final r in WasteReason.values) {
        expect(WasteReasonMeta.fromKey(r.persistKey), r);
      }
      expect(WasteReason.returned.persistKey, 'return');
      expect(WasteReason.staffError.persistKey, 'staff_error');
    });

    test('legacy değerler en yakın sebebe eşlenir (veri bozulmaz)', () {
      expect(WasteReasonMeta.fromKey('waste'), WasteReason.other);
      expect(WasteReasonMeta.fromKey('leftover'), WasteReason.overproduction);
      expect(WasteReasonMeta.fromKey(null), WasteReason.other);
      expect(WasteReasonMeta.fromKey('bilinmeyen'), WasteReason.other);
    });
  });

  group('bugün özeti + fire oranı', () {
    test('üretim + fire toplamları ve oran doğru', () async {
      final repo = LocalBakeryRepository();
      await repo.addProduction(prod('Ekmek', 100));
      await repo.addProduction(prod('Simit', 50));
      await repo.addWaste(waste('Ekmek', 15, reason: WasteReason.burnt));
      final s = await repo.dailySummary(today);
      expect(s.totalProduction, 150);
      expect(s.totalWaste, 15);
      expect(s.wasteRatio, closeTo(0.1, 1e-9));
    });

    test('üretim yoksa fire oranı null (— gösterilir)', () async {
      final repo = LocalBakeryRepository();
      await repo.addWaste(waste('Ekmek', 5));
      final s = await repo.dailySummary(today);
      expect(s.wasteRatio, isNull);
      // Boş gün doğru görünür.
      final empty = await repo.dailySummary(
        today.subtract(const Duration(days: 3)),
      );
      expect(empty.isEmpty, isTrue);
    });
  });

  group('günlük defter (ciro / not / kapanış)', () {
    test(
      'ciro upsert partial çalışır: null alan mevcut değeri korur',
      () async {
        final repo = LocalBakeryRepository();
        await repo.upsertDayBook(day: today, revenue: 4500);
        await repo.upsertDayBook(day: today, dayNote: 'İyi gündü');
        final book = await repo.dayBook(today);
        expect(book!.revenueAmount, 4500);
        expect(book.dayNote, 'İyi gündü');
        expect(book.isClosed, isFalse);
      },
    );

    test('gün kapatma + kapalı günde upsert reddi + yeniden açma', () async {
      final repo = LocalBakeryRepository();
      await repo.upsertDayBook(day: today, revenue: 1000);
      await repo.closeDay(today);
      expect((await repo.dayBook(today))!.isClosed, isTrue);
      expect(
        () => repo.upsertDayBook(day: today, revenue: 2000),
        throwsA(
          isA<StateError>().having(
            (e) => e.message,
            'message',
            contains('yeniden aç'),
          ),
        ),
      );
      await repo.reopenDay(today);
      expect((await repo.dayBook(today))!.isClosed, isFalse);
      await repo.upsertDayBook(day: today, revenue: 2000);
      expect((await repo.dayBook(today))!.revenueAmount, 2000);
    });

    test('hiç kaydı olmayan gün kapatılabilir (boş gün kapanışı)', () async {
      final repo = LocalBakeryRepository();
      await repo.closeDay(today);
      expect((await repo.dayBook(today))!.isClosed, isTrue);
    });
  });

  group('görevler (Bugün ne yapacağım?)', () {
    test('oluştur / tamamla / geri al / sil', () async {
      final repo = LocalBakeryRepository();
      final id = await repo.addTask(day: today, title: 'Sabah kontrolü');
      var list = await repo.tasks(today);
      expect(list.single.title, 'Sabah kontrolü');
      expect(list.single.isDone, isFalse);

      await repo.setTaskDone(id, true);
      list = await repo.tasks(today);
      expect(list.single.isDone, isTrue);

      await repo.setTaskDone(id, false);
      expect((await repo.tasks(today)).single.isDone, isFalse);

      await repo.deleteTask(id);
      expect(await repo.tasks(today), isEmpty);
    });

    test('boş başlık reddedilir; görevler güne bağlıdır', () async {
      final repo = LocalBakeryRepository();
      expect(
        () => repo.addTask(day: today, title: '  '),
        throwsA(isA<StateError>()),
      );
      await repo.addTask(day: today, title: 'Bugünün işi');
      expect(
        await repo.tasks(today.subtract(const Duration(days: 1))),
        isEmpty,
      );
    });
  });

  group('LedgerRangeReport.build — dönem hesabı', () {
    test('toplamlar + kapatılan gün + en çok fire ürünleri + notlar', () {
      final report = LedgerRangeReport.build(
        from: today.subtract(const Duration(days: 6)),
        to: today,
        production: [prod('Ekmek', 700), prod('Simit', 300)],
        wastes: [
          waste('Ekmek', 40),
          waste('Ekmek', 10, unitValue: 10),
          waste('Simit', 25),
        ],
        dayBooks: [
          BakeryDayBook(
            id: 'b1',
            businessDate: today,
            revenueAmount: 5000,
            dayNote: 'Bugün yoğundu',
            isClosed: true,
          ),
          BakeryDayBook(
            id: 'b2',
            businessDate: today.subtract(const Duration(days: 1)),
            revenueAmount: 4000,
          ),
        ],
      );
      expect(report.totalProduction, 1000);
      expect(report.totalWaste, 75);
      expect(report.wasteRatio, closeTo(0.075, 1e-9));
      expect(report.totalEstimatedLoss, 40 * 5 + 10 * 10 + 25 * 5);
      expect(report.totalRevenue, 9000);
      expect(report.closedDays, 1);
      // En çok fire: Ekmek(50) > Simit(25).
      expect(report.topWasteProducts.first, ('Ekmek', 50));
      expect(report.topWasteProducts[1], ('Simit', 25));
      expect(report.recentDayNotes.single.$2, 'Bugün yoğundu');
    });

    test('LocalRepo rangeReport gün aralığını doğru filtreler', () async {
      final repo = LocalBakeryRepository();
      await repo.addProduction(prod('Ekmek', 10));
      await repo.addProduction(
        prod('Ekmek', 99, at: today.subtract(const Duration(days: 40))),
      );
      await repo.upsertDayBook(day: today, revenue: 100);
      final r = await repo.rangeReport(
        today.subtract(const Duration(days: 29)),
        today,
      );
      expect(r.totalProduction, 10); // 40 gün önceki dahil DEĞİL
      expect(r.totalRevenue, 100);
    });
  });

  group('rapor dönemleri — yerel gün aralıkları (deterministik)', () {
    test('bugün/dün/7/30 sınırları doğru', () {
      final now = DateTime(2026, 7, 10, 23, 45); // gece geç saat
      final t = LedgerReportPeriod.today.range(now);
      expect(t.from, DateTime(2026, 7, 10));
      expect(t.to, DateTime(2026, 7, 10));
      final y = LedgerReportPeriod.yesterday.range(now);
      expect(y.from, DateTime(2026, 7, 9));
      expect(y.to, DateTime(2026, 7, 9));
      final w = LedgerReportPeriod.week7.range(now);
      expect(w.from, DateTime(2026, 7, 4));
      expect(w.to, DateTime(2026, 7, 10));
      final m = LedgerReportPeriod.month30.range(now);
      expect(m.from, DateTime(2026, 6, 11));
      expect(m.to, DateTime(2026, 7, 10));
    });
  });

  group('DailySummary geriye uyumluluk', () {
    test('mevcut alanlar bozulmadı', () {
      final s = DailySummary(
        day: today,
        production: [prod('Ekmek', 10)],
        deliveries: const [],
        wastes: [waste('Ekmek', 2, unitValue: 3)],
      );
      expect(s.totalProduction, 10);
      expect(s.totalWaste, 2);
      expect(s.totalEstimatedLoss, 6);
      expect(s.netAmount, -6);
    });
  });
}
