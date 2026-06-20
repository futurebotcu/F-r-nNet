import '../models/dealer.dart';
import '../models/dealer_driver.dart';
import '../models/dealer_driver_invite.dart';
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

  /// İşlemi siler/iptal eder (yanlış girilen kayıt). Teslimat ise
  /// `dealer_delivery_items` satırı, diğer tipler `dealer_transactions`
  /// satırı silinir. Bakiye, silinen kayıt artık okunmadığı için yeniden
  /// hesaplanır. RLS owner-only (`*_delete_own`); patron aksiyonu.
  Future<void> deleteTransaction(DealerTransaction tx);

  // ---- Tam yetkili şoför yazımları (feature/dealer-driver-permission-levels)
  // Owner-only RLS şoföre kapalı; tam yetkili şoför bu işlemleri SECURITY
  // DEFINER RPC'ler üzerinden yapar (atama + permission_level='full' sunucuda
  // doğrulanır). Yarı yetkili şoför çağırmaz (decorator engeller).

  /// Mevcut kullanıcının (şoför) yetki seviyesi: 'full' herhangi aktif
  /// dealer_drivers kaydı tam yetkiliyse, aksi halde 'half'. Şoför değilse
  /// 'half' döner (etkisiz).
  Future<DriverPermission> myDriverPermission();

  /// Tam yetkili şoför atanmış bayide işlem siler (`driver_delete_transaction`
  /// RPC). Teslimat → delivery_item, diğerleri → dealer_transactions.
  Future<void> driverDeleteTransaction(DealerTransaction tx);

  /// Tam yetkili şoför atanmış bayide yeni aktif fiyat ekler
  /// (`driver_set_price` RPC; tarihçeli valid_from=bugün).
  Future<void> driverSetPrice({
    required String dealerId,
    required String productName,
    required double unitPrice,
  });

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
    DriverPermission permissionLevel = DriverPermission.half,
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

  /// Mevcut kullanıcının aktif dealer_drivers kayıt id'leri (şoför paneli
  /// "Hareketlerim/Raporlarım" için kendi driver_id filtresi). Read-only.
  Future<List<String>> myDriverIds();

  // ---- Şoför işlem yazma (Sprint 4 — yalnız RPC) ----

  // ---- Şoför daveti (Sprint 6 — güvenli davet/onay) ----

  /// Patron pending davet oluşturur (doğrudan aktif şoför YARATMAZ). Hedef,
  /// şoförün Ayarlar'da gördüğü FırınNet ID'si (FN-YYYY-NNNNNN); çözümleme
  /// sunucuda (create_driver_invite RPC) yapılır — client lookup/arama yok.
  Future<void> createDriverInvite({
    required String firinnetId,
    required String name,
    String phone = '',
    String note = '',
    DriverPermission permissionLevel = DriverPermission.half,
  });

  /// Patronun bekleyen davetleri (Şoförler listesi "Bekleyen Davetler").
  Future<List<DealerDriverInvite>> pendingDriverInvites();

  /// Mevcut kullanıcıya (şoför) gelen bekleyen davetler.
  Future<List<DealerDriverInvite>> myDriverInvites();

  /// Şoför daveti yanıtlar. accept=true → aktif dealer_drivers oluşur.
  Future<void> respondDriverInvite(String inviteId, {required bool accept});

  /// Patron kendi bekleyen davetini iptal eder.
  Future<void> cancelDriverInvite(String inviteId);

  /// Şoför, atandığı bayiye işlem yazar (yalnız delivery/payment/return).
  /// Supabase'de `driver_add_transaction` SECURITY DEFINER RPC çağrılır:
  /// owner_id=patron, driver_id=ilgili dealer_drivers kaydı (tek defter).
  /// Yetki/atama doğrulaması sunucuda yapılır; adjustment şoföre kapalı.
  Future<void> addDriverTransaction({
    required String dealerId,
    required DealerTransactionType type,
    double amount = 0,
    int? quantity,
    double? unitPrice,
    DealerPaymentMethod? paymentMethod,
    String? productName,
    String note = '',
  });

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
