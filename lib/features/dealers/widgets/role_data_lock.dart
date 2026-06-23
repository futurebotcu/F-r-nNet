import 'package:flutter/material.dart';

/// Rol/Scope veri kilidi (role_data_lock) — DB guard'larının (respond_driver_
/// invite + profiles account_type trigger) fırlattığı hatayı yakalayıp
/// kullanıcıya açıklayan ortak yardımcılar.
///
/// Asıl blok DB'de; bu yalnız UI açıklamasıdır.

/// DB'den gelen hata bir role_data_lock mı?
bool isRoleDataLockError(Object error) =>
    error.toString().contains('role_data_lock');

/// Veri-kilidi açıklama popup'ı. [forInvite] true → şoför daveti kabulü;
/// false → profil tipi değişimi metni.
Future<void> showRoleDataLockDialog(
  BuildContext context, {
  required bool forInvite,
}) {
  final title = forInvite
      ? 'Önce mevcut kayıtlarını temizlemelisin'
      : 'Profil tipi değiştirilemiyor';
  final body = forInvite
      ? 'Bu hesapta kişisel Bayi Defteri veya işletme kayıtların var. Şoför '
          'olarak atanırsan başka bir işletmenin defteriyle çalışırsın. '
          'Kayıtların karışmaması için önce mevcut kayıtlarını silmen veya '
          'ileride aktarım özelliğiyle taşıman gerekir.'
      : 'Bu hesapta mevcut kayıtların var. Profil tipini değiştirmek bu '
          'verilere erişimi karıştırabilir. Kendi güvenliğin için önce '
          'verileri silmen veya aktarman gerekir.';
  return showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: Text(body),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(),
          child: const Text('Tamam'),
        ),
      ],
    ),
  );
}
