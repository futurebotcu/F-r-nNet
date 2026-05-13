/// Sektör grupları için kategori taksonomisi.
enum GroupCategory {
  bakers,      // Fırıncılar Genel
  flour,       // Un & Hammadde
  dealer,      // Bayi & Dağıtım
  equipment,   // Ekipman Alım Satım
  jobs,        // Usta İlanları
  recipe,      // Reçete & Üretim
  regional,    // Bölgesel Gruplar
  wholesale,   // Toptancılar
}

extension GroupCategoryLabel on GroupCategory {
  String get label {
    switch (this) {
      case GroupCategory.bakers:
        return 'Fırıncılar Genel';
      case GroupCategory.flour:
        return 'Un & Hammadde';
      case GroupCategory.dealer:
        return 'Bayi & Dağıtım';
      case GroupCategory.equipment:
        return 'Ekipman Alım Satım';
      case GroupCategory.jobs:
        return 'Usta İlanları';
      case GroupCategory.recipe:
        return 'Reçete & Üretim';
      case GroupCategory.regional:
        return 'Bölgesel Gruplar';
      case GroupCategory.wholesale:
        return 'Toptancılar';
    }
  }

  String get persistKey {
    switch (this) {
      case GroupCategory.bakers:
        return 'bakers';
      case GroupCategory.flour:
        return 'flour';
      case GroupCategory.dealer:
        return 'dealer';
      case GroupCategory.equipment:
        return 'equipment';
      case GroupCategory.jobs:
        return 'jobs';
      case GroupCategory.recipe:
        return 'recipe';
      case GroupCategory.regional:
        return 'regional';
      case GroupCategory.wholesale:
        return 'wholesale';
    }
  }

  static GroupCategory fromPersistKey(String key) {
    for (final c in GroupCategory.values) {
      if (c.persistKey == key) return c;
    }
    return GroupCategory.bakers;
  }
}
