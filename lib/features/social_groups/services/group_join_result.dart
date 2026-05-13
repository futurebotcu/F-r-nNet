/// `joinGroup(...)` çağrısının sonucu.
enum GroupJoinResult {
  success,
  full,
  alreadyJoined,
  notFound,
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
    }
  }
}
