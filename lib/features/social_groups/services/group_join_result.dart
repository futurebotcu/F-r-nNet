/// `joinGroup(...)` çağrısının sonucu.
enum GroupJoinResult {
  success,
  full,
  alreadyJoined,
  notFound,

  /// V1 P0 — Private grup için `joinGroup` yolu kapalı; üyelik yalnız
  /// `requestJoinGroup` + owner onayı zinciriyle. UI tarafı zaten private
  /// gruplar için doğru CTA'yı (`Katılma isteği gönder`) gösteriyor; bu
  /// değer defansif erken-reddetme — kart/handler bu sonucu görürse private
  /// flow'a yönlendirme yapmalı veya kullanıcıya bilgi vermelidir.
  requiresApproval,
}

extension GroupJoinResultLabel on GroupJoinResult {
  String get message {
    switch (this) {
      case GroupJoinResult.success:
        return 'Gruba katıldın.';
      case GroupJoinResult.full:
        return 'Grup dolu, katılım kapalı.';
      case GroupJoinResult.alreadyJoined:
        return 'Zaten bu gruptasın.';
      case GroupJoinResult.notFound:
        return 'Grup bulunamadı.';
      case GroupJoinResult.requiresApproval:
        return 'Bu grup katılım onaylı. Katılma isteği gönderebilirsin.';
    }
  }
}
