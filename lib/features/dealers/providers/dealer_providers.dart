import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;

import '../../../core/config/app_config.dart';
import '../../auth/providers/auth_providers.dart';
import '../../auth/providers/can_write_check_provider.dart';
import '../models/dealer.dart';
import '../models/dealer_balance_summary.dart';
import '../models/dealer_driver.dart';
import '../models/dealer_note.dart';
import '../models/driver_summary.dart';
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

/// "Borçlu Bayiler" Genel Bakış CTA için one-shot prefilter (Sprint 6B.x).
/// CTA bu provider'ı `true`'ya set eder ve [dealerShellTabIndexProvider]'ı
/// 1 yapar (Bayiler tab). [DealerListScreen] ilk build'inde değeri okur;
/// true ise filtre `_ActiveFilter.debtOnly`'a alınır ve provider false'a
/// sıfırlanır (one-shot). Kullanıcı manuel filtre değişikliği yaparsa
/// normal davranış sürer; provider tetiklenmediği sürece etkisizdir.
final dealerShellPrefilterDebtOnlyProvider = StateProvider<bool>((_) => false);

/// Genel Bakış "Son Hareketler" listesi (Sprint 6B). Tüm bayilerin son
/// N tx'ini desc sıralı döner. `listAllTransactions` zaten repo
/// tarafında sıralı; burada yalnız üstten kesilir.
final recentActivityProvider =
    FutureProvider.autoDispose<List<DealerTransaction>>((ref) async {
  ref.watch(dealerContentChangesProvider);
  final repo = ref.watch(dealerRepositoryProvider);
  final all = await repo.listAllTransactions();
  return all.take(5).toList();
});

/// Tüm tx listesi (Sprint 6B picker per-dealer balance hesabı için).
final allTransactionsProvider =
    FutureProvider.autoDispose<List<DealerTransaction>>((ref) async {
  ref.watch(dealerContentChangesProvider);
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
  // P0 kalıbı: yalnız userId izlenir (token refresh repo resetlemesin).
  final userId = ref.watch(currentAuthUserProvider.select((u) => u?.id));
  final DealerRepository inner;
  if (AppConfig.supabaseEnabled && userId != null) {
    inner = SupabaseDealerRepository(sb.Supabase.instance.client);
  } else {
    inner = LocalDealerRepository(seed: true);
  }
  final canWrite = ref.watch(canWriteCheckProvider);
  final repo = GuardedDealerRepository(inner: inner, canWriteCheck: canWrite);
  // Provider rebuild'inde (login/logout → userId değişir) eski repo'nun
  // broadcast controller'larını kapat (küçük leak önlenir).
  ref.onDispose(repo.dispose);
  return repo;
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

/// Repository YAPISAL değişiklik tick'i (bayi ekle/düzenle/aktif-pasif).
final dealerChangesProvider = StreamProvider<void>((ref) {
  final repo = ref.watch(dealerRepositoryProvider);
  return repo.watch();
});

/// Perf — yalnız İÇERİK (hareket/fiyat/not) değişim tick'i. Bir hareket
/// eklendiğinde SADECE ilgili bayinin tx/bakiye/aktivite slice'ı tazelenir;
/// tüm bayi listesi + diğer bayilerin bakiyesi recompute olmaz (storm önlenir).
final dealerContentChangesProvider = StreamProvider<void>((ref) {
  final repo = ref.watch(dealerRepositoryProvider);
  return repo.watchContent();
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
  ref.watch(dealerContentChangesProvider);
  final repo = ref.watch(dealerRepositoryProvider);
  return repo.listTransactions(id);
});

final pricesByDealerProvider = FutureProvider.autoDispose
    .family<List<DealerPrice>, String>((ref, id) async {
  ref.watch(dealerContentChangesProvider);
  final repo = ref.watch(dealerRepositoryProvider);
  return repo.listPrices(id);
});

final notesByDealerProvider = FutureProvider.autoDispose
    .family<List<DealerNote>, String>((ref, id) async {
  ref.watch(dealerContentChangesProvider);
  final repo = ref.watch(dealerRepositoryProvider);
  return repo.listNotes(id);
});

/// Patronun şoförleri (Sprint 2). Yapısal tick'i izler (şoför ekle/güncelle/
/// atama → yapısal `_notify`).
final driversListProvider =
    FutureProvider.autoDispose<List<DealerDriver>>((ref) async {
  ref.watch(dealerChangesProvider);
  final repo = ref.watch(dealerRepositoryProvider);
  return repo.listDrivers();
});

final driverByIdProvider =
    FutureProvider.autoDispose.family<DealerDriver?, String>((ref, id) async {
  ref.watch(dealerChangesProvider);
  final repo = ref.watch(dealerRepositoryProvider);
  return repo.getDriver(id);
});

/// Bir şoföre atanmış bayi id'leri (atama ekranı + detay).
final assignedDealerIdsProvider = FutureProvider.autoDispose
    .family<List<String>, String>((ref, driverId) async {
  ref.watch(dealerChangesProvider);
  final repo = ref.watch(dealerRepositoryProvider);
  return repo.assignedDealerIds(driverId);
});

/// Sprint 3 — mevcut kullanıcı aktif bir şoför mü (read-only görünüm gating'i).
final isAssignedDriverProvider =
    FutureProvider.autoDispose<bool>((ref) async {
  ref.watch(dealerChangesProvider);
  final repo = ref.watch(dealerRepositoryProvider);
  return repo.isAssignedDriver();
});

/// Sprint 3 — şoföre atanmış bayiler (read-only "Bana Atanan Bayiler").
final dealersAssignedToMeProvider =
    FutureProvider.autoDispose<List<Dealer>>((ref) async {
  ref.watch(dealerChangesProvider);
  final repo = ref.watch(dealerRepositoryProvider);
  return repo.dealersAssignedToMe();
});

/// Sprint 5 — Şoförler Genel Hesap: tüm şoför özeti + per-driver kırılım.
/// Kaynak: mevcut allTransactions (driver_id filtreli) + driversList. Yeni
/// hesap kuralı yok; DealerBalanceService.aggregateRange paylaşılır.
final driversGeneralSummaryProvider = FutureProvider.autoDispose
    .family<DriversGeneralSummary, DriverSummaryRange>((ref, rangeKind) async {
  ref.watch(dealerChangesProvider);
  ref.watch(dealerContentChangesProvider);
  final drivers = await ref.watch(driversListProvider.future);
  final allTx = await ref.watch(allTransactionsProvider.future);
  final svc = ref.watch(dealerBalanceServiceProvider);
  final range = rangeKind.range();

  // driver_id'ye göre grupla (NULL = patron işlemi → kırılıma DAHİL DEĞİL).
  final byDriver = <String, List<DealerTransaction>>{};
  for (final t in allTx) {
    final id = t.driverId;
    if (id == null || id.isEmpty) continue;
    (byDriver[id] ??= <DealerTransaction>[]).add(t);
  }

  final perDriver = <DriverRangeSummary>[];
  double tDelivery = 0, tReturn = 0, tPayment = 0, tNet = 0;
  var tCount = 0;
  for (final d in drivers) {
    final agg = svc.aggregateRange(
      transactions: byDriver[d.id] ?? const <DealerTransaction>[],
      start: range.start,
      end: range.end,
    );
    perDriver.add(DriverRangeSummary(
      driverId: d.id,
      name: d.name,
      isActive: d.isActive,
      assignedDealerCount: d.assignedDealerCount,
      totalDelivery: agg.totalDelivery,
      totalReturn: agg.totalReturn,
      totalPayment: agg.totalPayment,
      totalAdjustment: agg.totalAdjustment,
      netChange: agg.netChange,
      txCount: agg.txCount,
    ));
    tDelivery += agg.totalDelivery;
    tReturn += agg.totalReturn;
    tPayment += agg.totalPayment;
    tNet += agg.netChange;
    tCount += agg.txCount;
  }

  return DriversGeneralSummary(
    totalDrivers: drivers.length,
    activeDrivers: drivers.where((d) => d.isActive).length,
    totalDelivery: tDelivery,
    totalReturn: tReturn,
    totalPayment: tPayment,
    netChange: tNet,
    txCount: tCount,
    perDriver: perDriver,
  );
});

/// Sprint 5 — tek şoför özeti (patron şoför detayı için).
final driverRangeSummaryProvider = FutureProvider.autoDispose.family<
    DriverRangeSummary,
    ({String driverId, DriverSummaryRange range})>((ref, q) async {
  ref.watch(dealerChangesProvider);
  ref.watch(dealerContentChangesProvider);
  final allTx = await ref.watch(allTransactionsProvider.future);
  final driver = await ref.watch(driverByIdProvider(q.driverId).future);
  final svc = ref.watch(dealerBalanceServiceProvider);
  final range = q.range.range();
  final mine = allTx.where((t) => t.driverId == q.driverId);
  final agg = svc.aggregateRange(
      transactions: mine, start: range.start, end: range.end);
  return DriverRangeSummary(
    driverId: q.driverId,
    name: driver?.name ?? '',
    isActive: driver?.isActive ?? true,
    assignedDealerCount: driver?.assignedDealerCount ?? 0,
    totalDelivery: agg.totalDelivery,
    totalReturn: agg.totalReturn,
    totalPayment: agg.totalPayment,
    totalAdjustment: agg.totalAdjustment,
    netChange: agg.netChange,
    txCount: agg.txCount,
  );
});

/// Sprint 5 — bir şoförün son işlemleri (driver_id filtreli, desc).
final driverRecentTransactionsProvider = FutureProvider.autoDispose
    .family<List<DealerTransaction>, String>((ref, driverId) async {
  ref.watch(dealerContentChangesProvider);
  final allTx = await ref.watch(allTransactionsProvider.future);
  return allTx.where((t) => t.driverId == driverId).take(50).toList();
});

/// Bayi bakiye özeti (transactions üzerinden hesaplanır).
final balanceSummaryProvider = FutureProvider.autoDispose
    .family<DealerBalanceSummary, String>((ref, id) async {
  // Bakiye = f(transactions) → içerik tick'ini izler; hareket eklenince
  // anında günceller, dealer metadata düzenlemesinde gereksiz recompute yok.
  ref.watch(dealerContentChangesProvider);
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

/// Tüm **aktif** bayiler üzerinden `[start, end)` toplu agregat
/// metrikleri (Sprint Raporlar). Per-dealer dağılım [perDealerNet]
/// içinde döner — UI listede her bayi için bu periyottaki net'i
/// göstermek için kullanır. `allTransactionsProvider` cache'ini
/// paylaşır — Genel Bakış zaten yüklemişse ekstra round-trip yok.
final allDealersRangeMetricsProvider = FutureProvider.autoDispose
    .family<DealerAggregateRangeMetrics, ({DateTime start, DateTime end})>(
        (ref, q) async {
  final all = await ref.watch(dealersListProvider.future);
  final allTx = await ref.watch(allTransactionsProvider.future);
  final svc = ref.watch(dealerBalanceServiceProvider);

  // Quality Patch v1 P0-4: allTx'i bir kez dealerId'ye göre groupBy yap;
  // eskiden her bayi için `allTx.where(...)` ile O(N×M) taranırdı.
  // Aktif bayilerin id'leri filter set'i — pasif bayilerin tx'i atlanır.
  final activeIds = {for (final d in all) if (d.isActive) d.id};
  final byDealer = <String, List<DealerTransaction>>{};
  for (final t in allTx) {
    if (!activeIds.contains(t.dealerId)) continue;
    (byDealer[t.dealerId] ??= <DealerTransaction>[]).add(t);
  }

  final active = all.where((d) => d.isActive).toList();
  final perDealerNet = <String, double>{};
  final perDealerTxCount = <String, int>{};
  double totalDelivery = 0;
  double totalReturn = 0;
  double totalPayment = 0;
  double totalAdjustment = 0;
  double netChange = 0;
  int txCount = 0;

  for (final d in active) {
    final txs = byDealer[d.id] ?? const <DealerTransaction>[];
    final m = svc.summarizeRange(
      dealerId: d.id,
      transactions: txs,
      start: q.start,
      end: q.end,
    );
    perDealerNet[d.id] = m.netChange;
    perDealerTxCount[d.id] = m.txCount;
    totalDelivery += m.totalDelivery;
    totalReturn += m.totalReturn;
    totalPayment += m.totalPayment;
    totalAdjustment += m.totalAdjustment;
    netChange += m.netChange;
    txCount += m.txCount;
  }

  return DealerAggregateRangeMetrics(
    start: q.start,
    end: q.end,
    totalDelivery: totalDelivery,
    totalReturn: totalReturn,
    totalPayment: totalPayment,
    totalAdjustment: totalAdjustment,
    netChange: netChange,
    txCount: txCount,
    activeDealerCount: active.length,
    perDealerNet: perDealerNet,
    perDealerTxCount: perDealerTxCount,
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
  // Panel hero: hem dealer SAYISI (yapısal: ekle/aktif-pasif) hem de tüm
  // hareket toplamı (içerik) değişince güncellenmeli → iki tick birden.
  ref.watch(dealerChangesProvider);
  ref.watch(dealerContentChangesProvider);
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

  // Quality Patch v1 P0-2: bu ay net change + tx count + bugün gross
  // delivery/payment hesabı artık manuel switch loop'u DEĞİL,
  // DealerBalanceService.aggregateRange üzerinden — tx-type → katkı
  // kuralı [summarizeRange] ile tek kaynak.
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final tomorrow = today.add(const Duration(days: 1));
  final monthRange = DealerPeriod.thisMonth(now: now);

  final monthAgg = svc.aggregateRange(
    transactions: allTx,
    start: monthRange.start,
    end: monthRange.end,
  );
  final todayAgg = svc.aggregateRange(
    transactions: allTx,
    start: today,
    end: tomorrow,
  );

  return DealerOverview(
    totalDealers: all.length,
    activeDealers: activeCount,
    openBalance: openBalance,
    todayDelivered: todayAgg.totalDelivery,
    todayCollected: todayAgg.totalPayment,
    monthNetChange: monthAgg.netChange,
    monthTxCount: monthAgg.txCount,
  );
});
