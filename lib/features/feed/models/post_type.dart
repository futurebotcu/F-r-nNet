import 'package:flutter/material.dart';

import '../../../app/theme/app_colors.dart';

/// Feed gönderi türü — kart başlığında renkli rozet ile gösterilir.
/// `groupHighlight` özel: gerçek bir kullanıcı paylaşımı değil, popüler
/// bir grubun pinned mesajından üretilen feed enjeksiyonu.
enum PostType {
  production, // Üretim paylaşımı (atölyeden)
  question,   // Soru
  supply,     // Tedarik duyurusu
  equipment,  // Ekipman ilanı
  job,        // Usta arayışı / iş
  groupHighlight, // Gruptan öne çıkan mesaj
}

extension PostTypeMeta on PostType {
  String get label {
    switch (this) {
      case PostType.production:
        return 'Üretim';
      case PostType.question:
        return 'Soru';
      case PostType.supply:
        return 'Tedarik';
      case PostType.equipment:
        return 'Ekipman';
      case PostType.job:
        return 'İş';
      case PostType.groupHighlight:
        return 'Gruptan';
    }
  }

  IconData get icon {
    switch (this) {
      case PostType.production:
        return Icons.bakery_dining_rounded;
      case PostType.question:
        return Icons.help_outline_rounded;
      case PostType.supply:
        return Icons.local_shipping_rounded;
      case PostType.equipment:
        return Icons.build_rounded;
      case PostType.job:
        return Icons.work_rounded;
      case PostType.groupHighlight:
        return Icons.forum_rounded;
    }
  }

  /// Rozet ve vurgu rengi.
  Color get accent {
    switch (this) {
      case PostType.production:
        return AppColors.softGold;
      case PostType.question:
        return AppColors.info;
      case PostType.supply:
        return AppColors.success;
      case PostType.equipment:
        return AppColors.copper;
      case PostType.job:
        return AppColors.softGold;
      case PostType.groupHighlight:
        return AppColors.copper;
    }
  }

  String get persistKey {
    switch (this) {
      case PostType.production:
        return 'production';
      case PostType.question:
        return 'question';
      case PostType.supply:
        return 'supply';
      case PostType.equipment:
        return 'equipment';
      case PostType.job:
        return 'job';
      case PostType.groupHighlight:
        return 'group_highlight';
    }
  }

  static PostType fromPersistKey(String key) {
    for (final t in PostType.values) {
      if (t.persistKey == key) return t;
    }
    return PostType.production;
  }
}
