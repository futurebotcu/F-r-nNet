import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;

import '../../../core/config/app_config.dart';
import '../../auth/providers/auth_providers.dart';
import '../models/dealer.dart';
import '../models/dealer_balance_summary.dart';
import '../models/dealer_note.dart';
import '../models/dealer_price.dart';
import '../models/dealer_transaction.dart';
import '../repositories/dealer_repository.dart';
import '../repositories/local_dealer_repository.dart';
import '../repositories/supabase_dealer_repository.dart';
import '../services/dealer_balance_service.dart';
import '../services/dealer_pdf_builder.dart';
import '../services/dealer_share_builder.dart';

/// Dealer repository — Supabase yapılandırılmış + oturum açık ise Supabase
/// (hibrit: dealers + delivery'ler gerçek tabloya, payment/return/adjustment +
/// price + multi-note compose-local). Aksi halde tam local + demo seed.
final dealerRepositoryProvider = Provider<DealerRepository>((ref) {
  final user = ref.watch(currentAuthUserProvider);
  if (AppConfig.supabaseEnabled && user != null) {
    return SupabaseDealerRepository(sb.Supabase.instance.client);
  }
  return LocalDealerRepository(seed: true);
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
