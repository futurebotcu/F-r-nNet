import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;

import '../../../core/config/app_config.dart';
import '../../auth/providers/auth_providers.dart';
import '../../auth/providers/can_write_check_provider.dart';
import '../models/dealer.dart';
import '../models/dealer_balance_summary.dart';
import '../models/dealer_note.dart';
import '../models/dealer_price.dart';
import '../models/dealer_pulse_snapshot.dart';
import '../models/dealer_range_metrics.dart';
import '../models/dealer_transaction.dart';
import '../repositories/dealer_repository.dart';
import '../repositories/guarded_dealer_repository.dart';
import '../repositories/local_dealer_repository.dart';
import '../repositories/supabase_dealer_repository.dart';
import '../services/dealer_balance_service.dart';
import '../services/dealer_pdf_builder.dart';
import '../services/dealer_period.dart';
import '../services/dealer_pulse_service.dart';
import '../services/dealer_share_builder.dart';

/// Bayi Defteri mini-app shell aktif tab indeksi (Sprint 6B).
///
/// Önceki Sprint 6A'da [DealerShellScreen] kendi lokal state'ini
/// `setState` ile yönetiyordu; 6B'de Genel Bakış ekranındaki "Borçlu
/// Bayiler" / "Raporlar" CTA'ları başka tab'a programatik geçiş yapacağı
/// için indeks Riverpod provider'a taşındı. Default 0 (Genel Bakış).
final dealerShellTabIndexProvider = StateProvider<int>((_) => 0);

/// Genel Bakış "Son Hareketler" listesi (Sprint 6B). Tüm bayilerin son
/// N tx'ini desc sıralı döner. `listAllTransactions` zaten repo
/// tarafında sıralı; burada yalnız üstten kesilir.
final recentActivityProvider =
    FutureProvider.autoDispose<List<DealerTransaction>>((ref) async {
  ref.watch(dealerChangesProvider);
  final repo = ref.watch(dealerRepositoryProvider);
  final all = await repo.listAllTransactions();
  return all.take(5).toList();
});

/// Tüm tx listesi (Sprint 6B picker per-dealer balance hesabı için).
final allTransactionsProvider =
    FutureProvider.autoDispose<List<DealerTransaction>>((ref) async {
  ref.watch(dealerChangesProvider);
  final repo = ref.watch(dealerRepositoryProvider);
  return repo.listAllTransactions();
});

/// Bayi Defteri Nabız servisi (Sprint 3.5, donor concept-lift EMA pattern).
final dealerPulseServiceProvider = Provider<DealerPulseService>((ref) {
  return const DealerPulseService();
});

/// Bayi Defteri "Nabız" snapshot (Sprint 3.5). Bugünün delivery/payment/
/// netChange'i + son 20 non-empty gün EMA baseline'ı. Mevcut
/// `allTransactionsProvider` cache'ini paylaşır — backend dokunulmaz.
final dealerPulseProvider =
    FutureProvider.autoDispose<DealerPulseSnapshot>((ref) async {
  final txs = await ref.watch(allTransactionsProvider.future);
  final svc = ref.watch(dealerPulseServiceProvider);
  return svc.compute(transactions: txs);
});

/// V1.3.3 — Guarded wrapper ile sarılı dealer repository.
final dealerRepositoryProvider = Provider<DealerRepository>((ref) {
  final user = ref.watch(currentAuthUserProvider);
  final DealerRepository inner;
  if (AppConfig.supabaseEnabled && user != null) {
    inner = SupabaseDealerRepository(sb.Supabase.instance.client);
  } else {
    inner = LocalDealerRepository(seed: true);
  }
  final canWrite = ref.watch(canWriteCheckProvider);
  return GuardedDealerRepository(inner: inner, canWriteCheck: canWrite);
});

final dealerBalanceServiceProvider = Provider<DealerBalanceService>((ref) {
  return const DealerBalanceService();
});

final dealerShareBuilderProvider = Provider<DealerShareBuilder>((ref) {
  return const DealerShareBuilder();
});

final dealerPdfBuilderProvider = Provider<DealerPdfBuilder>((ref) {
  return const DealerPdfBuilder();
});

/// Repository değişikliklerini dinleyen tick.
final dealerChangesProvider = StreamProvider<void>((ref) {
  final repo = ref.watch(dealerRepositoryProvider);
  return repo.watch();
});

/// Tüm bayiler (default tüm; aktif filtresi UI tarafında uygulanır).
final dealersListProvider =
    FutureProvider.autoDispose<List<Dealer>>((ref) async {
  ref.watch(dealerChangesProvider);
  final repo = ref.watch(dealerRepositoryProvider);
  return repo.listDealers();
});

/// customer_type'a göre filtrelenmiş bayi/müşteri listesi (V1.2).
/// Ticari `bakery_dealer`, toptancı `wholesale_customer` rolünde kullanılır.
final dealersByTypeProvider = FutureProvider.autoDispose
    .family<List<Dealer>, DealerCustomerType>((ref, type) async {
  ref.watch(dealerChangesProvider);
  final repo = ref.watch(dealerRepositoryProvider);
  return repo.listDealers(customerType: type);
});

/// Aktif bayiler (panel hero kartı için).
final activeDealersListProvider =
    FutureProvider.autoDispose<List<Dealer>>((ref) async {
  ref.watch(dealerChangesProvider);
  final repo = ref.watch(dealerRepositoryProvider);
  return repo.listDealers(activeOnly: true);
});

final dealerByIdProvider =
    FutureProvider.autoDispose.family<Dealer?, String>((ref, id) async {
  ref.watch(dealerChangesProvider);
  final repo = ref.watch(dealerRepositoryProvider);
  return repo.getDealer(id);
});

final transactionsByDealerProvider = FutureProvider.autoDispose
    .family<List<DealerTransaction>, String>((ref, id) async {
  ref.watch(dealerChangesProvider);
  final repo = ref.watch(dealerRepositoryProvider);
  return repo.listTransactions(id);
});

final pricesByDealerProvider = FutureProvider.autoDispose
    .family<List<DealerPrice>, String>((ref, id) async {
  ref.watch(dealerChangesProvider);
  final repo = ref.watch(dealerRepositoryProvider);
  return repo.listPrices(id);
});

final notesByDealerProvider = FutureProvider.autoDispose
    .family<List<DealerNote>, String>((ref, id) async {
  ref.watch(dealerChangesProvider);
  final repo = ref.watch(dealerRepositoryProvider);
  return repo.listNotes(id);
});

/// Bayi bakiye özeti (transactions üzerinden hesaplanır).
final balanceSummaryProvider = FutureProvider.autoDispose
    .family<DealerBalanceSummary, String>((ref, id) async {
  ref.watch(dealerChangesProvider);
  final repo = ref.watch(dealerRepositoryProvider);
  final svc = ref.watch(dealerBalanceServiceProvider);
  final txs = await repo.listTransactions(id);
  return svc.summarize(dealerId: id, transactions: txs);
});

/// Bayi için verilen `[start, end)` aralığında metrik hesaplar.
/// `transactionsByDealerProvider` cache'ini paylaşır — aynı dealer için
/// detail ekranı zaten tx listesini çekmişse ekstra round-trip yok.
final dealerRangeMetricsProvider = FutureProvider.autoDispose
    .family<DealerRangeMetrics, ({String dealerId, DateTime start, DateTime end})>(
        (ref, q) async {
  final txs = await ref.watch(transactionsByDealerProvider(q.dealerId).future);
  final svc = ref.watch(dealerBalanceServiceProvider);
  return svc.summarizeRange(
    dealerId: q.dealerId,
    transactions: txs,
    start: q.start,
    end: q.end,
  );
});

/// Panel hero için global bayi yönetimi metrikleri.
class DealerOverview {
  const DealerOverview({
    required this.totalDealers,
    required this.activeDealers,
    required this.openBalance,
    required this.todayDelivered,
    required this.todayCollected,
    required this.monthNetChange,
    required this.monthTxCount,
  });

  final int totalDealers;
  final int activeDealers;

  /// Tüm aktif bayilerin pozitif bakiyelerinin toplamı (fırına olan açık borç).
  final double openBalance;

  /// Bugün yapılan teslimat toplam tutarı (TL).
  final double todayDelivered;

  /// Bugün alınan ödeme toplamı (TL).
  final double todayCollected;

  /// Bu ay (1'i 00:00 — gelecek ayın 1'i 00:00) net değişim.
  /// `delivery + adjustment − return − payment` formülü;
  /// `DealerBalanceService.summarize` ile aynı imzalı katkı kuralı.
  final double monthNetChange;

  /// Bu ay aralığındaki tx sayısı (tüm bayiler birleşik).
  final int monthTxCount;
}

final dealersOverviewProvider =
    FutureProvider.autoDispose<DealerOverview>((ref) async {
  ref.watch(dealerChangesProvider);
  final repo = ref.watch(dealerRepositoryProvider);
  final svc = ref.watch(dealerBalanceServiceProvider);

  final all = await repo.listDealers();
  final activeCount = all.where((d) => d.isActive).length;
  final allTx = await repo.listAllTransactions();

  double openBalance = 0;
  for (final d in all.where((d) => d.isActive)) {
    final s = svc.summarize(dealerId: d.id, transactions: allTx);
    if (s.currentBalance > 0) openBalance += s.currentBalance;
  }

  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final monthRange = DealerPeriod.thisMonth(now: now);
  double delivered = 0;
  double collected = 0;
  double monthNet = 0;
  int monthCount = 0;
  for (final t in allTx) {
    // Bu ay: signed katkı + tx count
    if (!t.createdAt.isBefore(monthRange.start) &&
        t.createdAt.isBefore(monthRange.end)) {
      monthCount++;
      switch (t.type) {
        case DealerTransactionType.delivery:
          monthNet += t.amount;
          break;
        case DealerTransactionType.returned:
          monthNet -= t.amount;
          break;
        case DealerTransactionType.payment:
          monthNet -= t.amount;
          break;
        case DealerTransactionType.adjustment:
          monthNet += t.amount;
          break;
      }
    }
    // Bugün: gross delivery + gross payment
    if (t.createdAt.isBefore(today)) continue;
    if (t.type == DealerTransactionType.delivery) delivered += t.amount;
    if (t.type == DealerTransactionType.payment) collected += t.amount;
  }

  return DealerOverview(
    totalDealers: all.length,
    activeDealers: activeCount,
    openBalance: openBalance,
    todayDelivered: delivered,
    todayCollected: collected,
    monthNetChange: monthNet,
    monthTxCount: monthCount,
  );
});
