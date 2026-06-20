/// Şoför, **patron yetkisi gerektiren** bir işlemi (bayi oluştur/düzenle/
/// aktif-pasif, fiyat ekle, düzeltme vb.) tetiklediğinde fırlatılır.
///
/// fix/driver-normal-dealer-shell ürün kuralı: şoför normal Bayi Yönetimi'ni
/// kullanır, owner aksiyon butonları **gizlenmez**; ama backend'in izin
/// vermediği yazımlarda ham `StateError`/crash yerine UI bu exception'ı
/// yakalayıp [driverPermissionMessage]'ı temiz snackbar olarak gösterir.
class DriverPermissionException implements Exception {
  const DriverPermissionException([this.message = driverPermissionMessage]);

  final String message;

  @override
  String toString() => message;
}

const String driverPermissionMessage = 'Bu işlem için patron yetkisi gerekir.';
