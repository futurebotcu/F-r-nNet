import 'package:flutter/foundation.dart';

/// Türk fırın ürünleri için ortak preset kataloğu.
///
/// Tek veri kaynağı — birden fazla modülü besler:
///   * Sabah Üretim Planlayıcı → varsayılan gramaj + pişme/fire
///   * Çuvaldan Kaç Ürün Çıkar? → gramaj + su kaldırma + fire
///   * Hamur Kıvamı (Su Oranı) → grup-bazlı ideal su oranı bandı
///
/// ÖNEMLİ: Tüm sayılar **ayarlanabilir varsayılan öneridir**, kesin gerçek
/// değildir. Ürün seçimi yalnızca alanları ön-doldurur; kullanıcı her değeri
/// elle değiştirebilir ve ürün seçmezse mevcut davranış korunur. Matematik
/// içermez (saf veri).

/// Ürün grubu — kıvam (su oranı) eşikleri grup düzeyinde tutulur.
enum BakeryProductGroup {
  genelEkmek,
  tamBugday,
  simit,
  pogacaAcma,
  pideLavasBazlama,
  kurabiye,
  manual,
}

/// Bir ürün grubu için önerilen su oranı (su/un %) eşik bandı.
@immutable
class HydrationBand {
  const HydrationBand({
    required this.stiffBelow,
    required this.idealLow,
    required this.idealHigh,
  });

  /// Altı "çok sert".
  final double stiffBelow;

  /// İdeal bandın altı (= "su az" eşiği).
  final double idealLow;

  /// İdeal bandın üstü (= "su fazla" eşiği).
  final double idealHigh;
}

extension BakeryProductGroupMeta on BakeryProductGroup {
  String get displayName {
    switch (this) {
      case BakeryProductGroup.genelEkmek:
        return 'Genel / Somun Ekmek';
      case BakeryProductGroup.tamBugday:
        return 'Tam Buğday';
      case BakeryProductGroup.simit:
        return 'Simit';
      case BakeryProductGroup.pogacaAcma:
        return 'Poğaça / Açma';
      case BakeryProductGroup.pideLavasBazlama:
        return 'Pide / Lavaş / Bazlama';
      case BakeryProductGroup.kurabiye:
        return 'Kurabiye';
      case BakeryProductGroup.manual:
        return 'Manuel';
    }
  }

  /// Grup için önerilen ideal su oranı bandı (ayarlanabilir varsayılan).
  /// [manual] için null → kıvam modülünde genel varsayılan eşik kullanılır.
  HydrationBand? get hydrationBand {
    switch (this) {
      case BakeryProductGroup.genelEkmek:
        return const HydrationBand(stiffBelow: 58, idealLow: 60, idealHigh: 66);
      case BakeryProductGroup.tamBugday:
        return const HydrationBand(stiffBelow: 64, idealLow: 66, idealHigh: 74);
      case BakeryProductGroup.simit:
        return const HydrationBand(stiffBelow: 46, idealLow: 48, idealHigh: 55);
      case BakeryProductGroup.pogacaAcma:
        return const HydrationBand(stiffBelow: 46, idealLow: 48, idealHigh: 58);
      case BakeryProductGroup.pideLavasBazlama:
        return const HydrationBand(stiffBelow: 56, idealLow: 58, idealHigh: 64);
      case BakeryProductGroup.kurabiye:
        return const HydrationBand(stiffBelow: 28, idealLow: 30, idealHigh: 42);
      case BakeryProductGroup.manual:
        return null;
    }
  }
}

/// Tek bir ürün preset'i. Değerler **ayarlanabilir varsayılan**dır.
@immutable
class TurkishBakeryProductPreset {
  const TurkishBakeryProductPreset({
    required this.id,
    required this.displayName,
    required this.group,
    this.defaultDoughWeightG = 0,
    this.defaultHydrationPct = 0,
    this.defaultBakeLossPct = 0,
    this.note,
    this.isManual = false,
  });

  /// Kararlı, benzersiz kimlik.
  final String id;
  final String displayName;
  final BakeryProductGroup group;

  /// Pişme öncesi hamur gramajı (gr) — varsayılan öneri.
  final double defaultDoughWeightG;

  /// Su / un oranı (%) — "su kaldırma oranı" varsayılanı.
  final double defaultHydrationPct;

  /// Pişme / fire oranı (%) — varsayılan öneri.
  final double defaultBakeLossPct;

  final String? note;

  /// "Diğer / Manuel" girişi (alanları otomatik doldurmaz).
  final bool isManual;
}

/// Türk fırın ürünleri kataloğu (tek kayıt noktası).
class TurkishBakeryProducts {
  const TurkishBakeryProducts._();

  static const List<TurkishBakeryProductPreset> all =
      <TurkishBakeryProductPreset>[
        TurkishBakeryProductPreset(
          id: 'somun_250',
          displayName: 'Somun Ekmek 250g',
          group: BakeryProductGroup.genelEkmek,
          defaultDoughWeightG: 330,
          defaultHydrationPct: 60,
          defaultBakeLossPct: 12,
        ),
        TurkishBakeryProductPreset(
          id: 'somun_300',
          displayName: 'Somun Ekmek 300g',
          group: BakeryProductGroup.genelEkmek,
          defaultDoughWeightG: 400,
          defaultHydrationPct: 60,
          defaultBakeLossPct: 12,
        ),
        TurkishBakeryProductPreset(
          id: 'tam_bugday',
          displayName: 'Tam Buğday Ekmek',
          group: BakeryProductGroup.tamBugday,
          defaultDoughWeightG: 340,
          defaultHydrationPct: 70,
          defaultBakeLossPct: 12,
          note: 'Tam buğday/kepekli un daha çok su çeker.',
        ),
        TurkishBakeryProductPreset(
          id: 'sandvic',
          displayName: 'Sandviç Ekmeği',
          group: BakeryProductGroup.genelEkmek,
          defaultDoughWeightG: 90,
          defaultHydrationPct: 62,
          defaultBakeLossPct: 10,
        ),
        TurkishBakeryProductPreset(
          id: 'hamburger',
          displayName: 'Hamburger Ekmeği',
          group: BakeryProductGroup.genelEkmek,
          defaultDoughWeightG: 75,
          defaultHydrationPct: 60,
          defaultBakeLossPct: 10,
        ),
        TurkishBakeryProductPreset(
          id: 'tost',
          displayName: 'Tost Ekmeği',
          group: BakeryProductGroup.genelEkmek,
          defaultDoughWeightG: 750,
          defaultHydrationPct: 62,
          defaultBakeLossPct: 9,
          note: 'Kalıp ekmek; tek somun gramajı.',
        ),
        TurkishBakeryProductPreset(
          id: 'ramazan_pidesi',
          displayName: 'Ramazan Pidesi',
          group: BakeryProductGroup.pideLavasBazlama,
          defaultDoughWeightG: 300,
          defaultHydrationPct: 64,
          defaultBakeLossPct: 9,
        ),
        TurkishBakeryProductPreset(
          id: 'pide',
          displayName: 'Pide',
          group: BakeryProductGroup.pideLavasBazlama,
          defaultDoughWeightG: 250,
          defaultHydrationPct: 60,
          defaultBakeLossPct: 9,
        ),
        TurkishBakeryProductPreset(
          id: 'lavas',
          displayName: 'Lavaş',
          group: BakeryProductGroup.pideLavasBazlama,
          defaultDoughWeightG: 120,
          defaultHydrationPct: 58,
          defaultBakeLossPct: 7,
        ),
        TurkishBakeryProductPreset(
          id: 'bazlama',
          displayName: 'Bazlama',
          group: BakeryProductGroup.pideLavasBazlama,
          defaultDoughWeightG: 150,
          defaultHydrationPct: 58,
          defaultBakeLossPct: 8,
        ),
        TurkishBakeryProductPreset(
          id: 'simit',
          displayName: 'Simit',
          group: BakeryProductGroup.simit,
          defaultDoughWeightG: 110,
          defaultHydrationPct: 52,
          defaultBakeLossPct: 9,
          note: 'Simit hamuru daha serttir.',
        ),
        TurkishBakeryProductPreset(
          id: 'acma',
          displayName: 'Açma',
          group: BakeryProductGroup.pogacaAcma,
          defaultDoughWeightG: 65,
          defaultHydrationPct: 54,
          defaultBakeLossPct: 9,
          note: 'Yağlı hamur; su oranı yağla birlikte değerlendirilir.',
        ),
        TurkishBakeryProductPreset(
          id: 'pogaca',
          displayName: 'Poğaça',
          group: BakeryProductGroup.pogacaAcma,
          defaultDoughWeightG: 70,
          defaultHydrationPct: 52,
          defaultBakeLossPct: 9,
          note: 'Yağlı hamur; su oranı yağla birlikte değerlendirilir.',
        ),
        TurkishBakeryProductPreset(
          id: 'tuzlu_kurabiye',
          displayName: 'Tuzlu Kurabiye',
          group: BakeryProductGroup.kurabiye,
          defaultDoughWeightG: 30,
          defaultHydrationPct: 36,
          defaultBakeLossPct: 7,
          note: 'Çok sert/yağlı hamur.',
        ),
        TurkishBakeryProductPreset(
          id: 'manual',
          displayName: 'Diğer / Manuel',
          group: BakeryProductGroup.manual,
          isManual: true,
        ),
      ];

  /// "Diğer / Manuel" preset'i.
  static TurkishBakeryProductPreset get manual =>
      all.firstWhere((p) => p.isManual);

  /// Kıvam modülü için grup seçenekleri (manuel hariç — grup başına ideal band).
  static const List<BakeryProductGroup> hydrationGroups = <BakeryProductGroup>[
    BakeryProductGroup.genelEkmek,
    BakeryProductGroup.tamBugday,
    BakeryProductGroup.simit,
    BakeryProductGroup.pogacaAcma,
    BakeryProductGroup.pideLavasBazlama,
    BakeryProductGroup.kurabiye,
  ];
}
