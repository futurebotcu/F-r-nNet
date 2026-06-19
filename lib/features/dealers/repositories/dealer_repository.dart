import '../models/dealer.dart';
import '../models/dealer_driver.dart';
import '../models/dealer_note.dart';
import '../models/dealer_price.dart';
import '../models/dealer_transaction.dart';

/// Bayi yönetimi için soyut erişim.
///
/// V1.2:
/// - LocalDealerRepository: in-memory, demo seed; customer_type filtresini
///   destekler (ticari ve toptancı UI'sı aynı arayüzü kullanır).
/// - SupabaseDealerRepository: Migration A sonrası tüm transaction/price/note
///   kalıcı tabloya yazılır. dealer_deliveries + dealer_delivery_items hâlâ
///   teslimat satırı için kullanılır (`type=delivery` okumaları oradan gelir).
abstract class DealerRepository {
  // Dealers
  Future<List<Dealer>> listDealers({
    bool? activeOnly,
    DealerCustomerType? customerType,
  });
  Future<Dealer?> getDealer(String id);
  Future<void> upsertDealer(Dealer dealer);
  Future<void> setActive(String dealerId, {required bool active});

  // Prices
  Future<List<DealerPrice>> listPrices(String dealerId);

  /// Belirli bayi+ürün için "şu an geçerli" fiyat (en son `validFrom`).
  /// Yoksa null.
  Future<DealerPrice?> currentPriceFor({
    required String dealerId,
    required String productName,
  });

  Future<void> addPrice(DealerPrice price);

  // Transactions
  Future<List<DealerTransaction>> listTransactions(String dealerId);
  Future<List<DealerTransaction>> listAllTransactions();
  Future<void> addTransaction(DealerTransaction tx);

  // Notes
  Future<List<DealerNote>> listNotes(String dealerId);
  Future<void> addNote(DealerNote note);

  // ---- Şoförler (Sprint 2: patron-side yönetim) ----
  // owner_id daima patron; bu sprintte şoför login erişimi/yazma YOK.

  /// Patronun kendi şoförleri (assignedDealerCount dolu).
  Future<List<DealerDriver>> listDrivers();

  Future<DealerDriver?> getDriver(String driverId);

  /// Yeni şoför ekler. [driverUserId] geçerli bir FırınNet profile id olmalı
  /// (Supabase'de FK doğrular). Aynı (owner, driverUserId) ikinci kez eklenemez.
  Future<void> addDriver({
    required String driverUserId,
    required String name,
    String phone = '',
    String note = '',
  });

  /// Ad/telefon/not/aktiflik günceller.
  Future<void> updateDriver(DealerDriver driver);

  /// Bir şoföre atanmış bayi id'leri.
  Future<List<String>> assignedDealerIds(String driverId);

  /// Şoförün bayi atamasını verilen kümeye eşitler (ekle/çıkar). Yalnız
  /// patronun kendi bayileri; DB trigger cross-owner atamayı ayrıca reddeder.
  Future<void> setDriverAssignments({
    required String driverId,
    required List<String> dealerIds,
  });

  // ---- Şoför read-only görünümü (Sprint 3) ----

  /// Mevcut kullanıcı aktif bir şoför mü (kendisine ait dealer_drivers kaydı)?
  /// Read-only "Bana Atanan Bayiler" görünümü gating'i için.
  Future<bool> isAssignedDriver();

  /// Mevcut kullanıcıya (şoför) atanmış bayiler — read-only.
  Future<List<Dealer>> dealersAssignedToMe();

  /// Repository YAPISAL değişiklik yayını (bayi ekle/düzenle/aktif-pasif).
  Stream<void> watch();

  /// İÇERİK değişiklik yayını (hareket/fiyat/not). Yapısal tick'ten ayrı:
  /// bir hareket eklenince yalnız ilgili bayinin tx/bakiye slice'ı tazelenir,
  /// tüm bayi listesi recompute olmaz. (`implements` default body devralmaz —
  /// her impl override eder.)
  Stream<void> watchContent() => watch();

  /// Repo instance atıldığında (provider rebuild) controller'ları kapatma
  /// kancası. Default no-op; Supabase impl broadcast controller'larını kapatır.
  void dispose() {}
}
