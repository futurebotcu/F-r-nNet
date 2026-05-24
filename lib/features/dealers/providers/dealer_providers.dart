import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;

import '../../../core/config/app_config.dart';
import '../../auth/providers/auth_providers.dart';
import '../../auth/providers/can_write_check_provider.dart';
import '../models/dealer.dart';
import '../models/dealer_balance_summary.dart';
import '../models/dealer_note.dart';
import '../models/dealer_price.dart';
import '../models/dealer_range_metrics.dart';
import '../models/dealer_transaction.dart';
import '../repositories/dealer_repository.dart';
import '../repositories/guarded_dealer_repository.dart';
import '../repositories/local_dealer_repository.dart';
import '../repositories/supabase_dealer_repository.dart';
import '../services/dealer_balance_service.dart';
import '../services/dealer_pdf_builder.dart';
import '../services/dealer_share_builder.dart';

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
  });

  final int totalDealers;
  final int activeDealers;

  /// Tüm aktif bayilerin pozitif bakiyelerinin toplamı (fırına olan açık borç).
  final double openBalance;

  /// Bugün yapılan teslimat toplam tutarı (TL).
  final double todayDelivered;

  /// Bugün alınan ödeme toplamı (TL).
  final double todayCollected;
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
  double delivered = 0;
  double collected = 0;
  for (final t in allTx) {
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
  );
});
