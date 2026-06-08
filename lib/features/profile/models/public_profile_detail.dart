// FırınNet V1 Unified Profile M2 — public_profile_detail RPC modeli.
// M5 — profession_badge_code alanı eklendi (taxonomy code-aware display).
//
// RPC `public_profile_detail(uuid) returns jsonb` whitelisted aggregate
// veri döner. salary_expectation, email, phone gibi hassas alanlar
// RPC tarafında dahi seçilmez. Bu model yalnız UI render için.

import '../../../core/data/firinnet_taxonomy.dart';
import '../../../core/data/turkey_locations.dart';

class PublicProfileHeader {
  const PublicProfileHeader({
    required this.id,
    this.displayName,
    this.avatarUrl,
    this.accountType,
    this.professionBadge,
    this.professionBadgeCode,
    this.city,
    this.cityCode,
  });

  final String id;
  final String? displayName;
  final String? avatarUrl;

  /// `commercial` | `individual` | `wholesaler` (profiles.account_type)
  final String? accountType;

  /// Türkçe label (display fallback, backward compat).
  final String? professionBadge;

  /// M5 — ASCII code (`usta_firinci`, ...). Varsa taxonomy label öncelikli.
  final String? professionBadgeCode;

  /// Türkçe il adı (eski text, display fallback).
  final String? city;

  /// M6A — Türkiye plaka kodu (`34`, `42`, ...). Varsa
  /// `TurkeyLocations` label öncelikli.
  final String? cityCode;

  /// M6A öncelik sırası: code → taxonomy label → eski text fallback.
  String? get effectiveCity {
    final c = cityCode;
    if (c != null && c.isNotEmpty) {
      final prov = TurkeyLocations.findProvinceByCode(c);
      if (prov != null) return prov.name;
    }
    return city;
  }

  static PublicProfileHeader fromJson(Map<String, dynamic> j) {
    return PublicProfileHeader(
      id: j['id'] as String,
      displayName: j['display_name'] as String?,
      avatarUrl: j['avatar_url'] as String?,
      accountType: j['account_type'] as String?,
      professionBadge: j['profession_badge'] as String?,
      professionBadgeCode: j['profession_badge_code'] as String?,
      city: j['city'] as String?,
      cityCode: j['city_code'] as String?,
    );
  }
}

class PublicWorkerInfo {
  const PublicWorkerInfo({
    this.professionBadge,
    this.professionBadgeCode,
    this.experienceYears,
    this.cities = const <String>[],
    this.cityCodes = const <String>[],
    this.skills = const <String>[],
    this.skillCodes = const <String>[],
    this.shiftPreference,
    this.bio,
  });

  /// Türkçe label (display fallback, backward compat).
  final String? professionBadge;

  /// M5 — ASCII code; varsa taxonomy label öncelikli.
  final String? professionBadgeCode;

  final int? experienceYears;
  final List<String> cities;

  /// M6A — Türkiye plaka kodları. UI önce code'ları `TurkeyLocations`
  /// üzerinden çevirir; yoksa [cities] (eski label) fallback.
  final List<String> cityCodes;

  /// Türkçe label listesi (eski text, display fallback).
  final List<String> skills;

  /// M7 — ASCII skill code listesi. UI önce code'lardan
  /// `FirinnetTaxonomy` üzerinden çevirir; yoksa [skills] fallback.
  final List<String> skillCodes;

  final String? shiftPreference;
  final String? bio;

  bool get isEmpty =>
      (professionBadge == null || professionBadge!.isEmpty) &&
      (professionBadgeCode == null || professionBadgeCode!.isEmpty) &&
      experienceYears == null &&
      cities.isEmpty &&
      cityCodes.isEmpty &&
      skills.isEmpty &&
      skillCodes.isEmpty &&
      (shiftPreference == null || shiftPreference!.isEmpty) &&
      (bio == null || bio!.isEmpty);

  /// M6A — display için: önce code'ları label'a çevir, yoksa eski text.
  List<String> get effectiveCities {
    if (cityCodes.isNotEmpty) {
      return <String>[
        for (final c in cityCodes)
          TurkeyLocations.findProvinceByCode(c)?.name ?? c,
      ];
    }
    return cities;
  }

  /// M7 — skill display: önce skill_codes → taxonomy label, yoksa eski text.
  List<String> get effectiveSkills {
    if (skillCodes.isNotEmpty) {
      return <String>[
        for (final c in skillCodes) FirinnetTaxonomy.workerSkillLabel(c) ?? c,
      ];
    }
    return skills;
  }

  static PublicWorkerInfo fromJson(Map<String, dynamic> j) {
    List<String> asStringList(dynamic v) {
      if (v is List) {
        return v.whereType<String>().toList(growable: false);
      }
      return const <String>[];
    }

    return PublicWorkerInfo(
      professionBadge: j['profession_badge'] as String?,
      professionBadgeCode: j['profession_badge_code'] as String?,
      experienceYears: (j['experience_years'] as num?)?.toInt(),
      cities: asStringList(j['cities']),
      cityCodes: asStringList(j['city_codes']),
      skills: asStringList(j['skills']),
      skillCodes: asStringList(j['skill_codes']),
      shiftPreference: j['shift_preference'] as String?,
      bio: j['bio'] as String?,
    );
  }
}

class PublicWorkerExperience {
  const PublicWorkerExperience({
    required this.id,
    required this.title,
    this.workplace,
    this.city,
    this.cityCode,
    this.startDate,
    this.endDate,
    this.description,
    this.entryType = 'individual',
    this.isPublic = true,
  });

  final String id;
  final String title;

  /// CV Center — kurum / işletme / işyeri (RPC artık döndürüyor).
  final String? workplace;

  final String? city;

  /// M6A — plaka kodu. UI önce code'dan label çevirir.
  final String? cityCode;

  final DateTime? startDate;
  final DateTime? endDate;
  final String? description;

  /// CV Center — kayıt türü (individual/commercial/wholesaler/other).
  final String entryType;

  /// CV Center — görünürlük. RPC başkasına yalnız is_public=true döndürür;
  /// owner kendi tüm kayıtlarını görür (gizli olanlar UI'da işaretlenir).
  final bool isPublic;

  bool get isCurrent => endDate == null && startDate != null;

  /// M6A — display: code → label, yoksa eski text.
  String? get effectiveCity {
    final c = cityCode;
    if (c != null && c.isNotEmpty) {
      final prov = TurkeyLocations.findProvinceByCode(c);
      if (prov != null) return prov.name;
    }
    return city;
  }

  static PublicWorkerExperience fromJson(Map<String, dynamic> j) {
    DateTime? parse(String? s) => s == null ? null : DateTime.tryParse(s);
    return PublicWorkerExperience(
      id: j['id'] as String,
      title: (j['title'] as String?) ?? '',
      workplace: j['workplace'] as String?,
      city: j['city'] as String?,
      cityCode: j['city_code'] as String?,
      startDate: parse(j['start_date'] as String?),
      endDate: parse(j['end_date'] as String?),
      description: j['description'] as String?,
      entryType: (j['entry_type'] as String?) ?? 'individual',
      isPublic: (j['is_public'] as bool?) ?? true,
    );
  }
}

class PublicBakeryInfo {
  const PublicBakeryInfo({
    required this.id,
    required this.name,
    this.city,
    this.district,
    this.description,
  });

  final String id;
  final String name;
  final String? city;
  final String? district;
  final String? description;

  bool get isEmpty => name.isEmpty;

  static PublicBakeryInfo fromJson(Map<String, dynamic> j) {
    return PublicBakeryInfo(
      id: j['id'] as String,
      name: (j['name'] as String?) ?? '',
      city: j['city'] as String?,
      district: j['district'] as String?,
      description: j['description'] as String?,
    );
  }
}

class PublicProfileDetail {
  const PublicProfileDetail({
    required this.header,
    this.worker,
    this.experiences = const <PublicWorkerExperience>[],
    this.bakery,
  });

  final PublicProfileHeader header;
  final PublicWorkerInfo? worker;
  final List<PublicWorkerExperience> experiences;
  final PublicBakeryInfo? bakery;

  /// M5 öncelik sırası (code-aware):
  ///   1. worker.professionBadgeCode → taxonomy label
  ///   2. header.professionBadgeCode → taxonomy label
  ///   3. worker.professionBadge (eski Türkçe label)
  ///   4. header.professionBadge (eski Türkçe label)
  String? get effectiveProfessionBadge {
    final wc = worker?.professionBadgeCode;
    if (wc != null && wc.isNotEmpty) {
      final lbl = FirinnetTaxonomy.professionLabel(wc);
      if (lbl != null) return lbl;
    }
    final hc = header.professionBadgeCode;
    if (hc != null && hc.isNotEmpty) {
      final lbl = FirinnetTaxonomy.professionLabel(hc);
      if (lbl != null) return lbl;
    }
    final wt = worker?.professionBadge;
    if (wt != null && wt.isNotEmpty) return wt;
    return header.professionBadge;
  }

  bool get hasWorkerInfo => worker != null && !worker!.isEmpty;
  bool get hasExperiences => experiences.isNotEmpty;
  bool get hasBakery => bakery != null && !bakery!.isEmpty;

  static PublicProfileDetail? fromRpcJson(dynamic raw) {
    if (raw == null) return null;
    if (raw is! Map) return null;
    final m = Map<String, dynamic>.from(raw);
    final profile = m['profile'];
    if (profile is! Map) return null;
    final header = PublicProfileHeader.fromJson(
      Map<String, dynamic>.from(profile),
    );
    PublicWorkerInfo? worker;
    if (m['worker'] is Map) {
      worker = PublicWorkerInfo.fromJson(
        Map<String, dynamic>.from(m['worker'] as Map),
      );
    }
    final experiences = <PublicWorkerExperience>[];
    if (m['experiences'] is List) {
      for (final e in (m['experiences'] as List)) {
        if (e is Map) {
          experiences.add(
            PublicWorkerExperience.fromJson(Map<String, dynamic>.from(e)),
          );
        }
      }
    }
    PublicBakeryInfo? bakery;
    if (m['bakery'] is Map) {
      bakery = PublicBakeryInfo.fromJson(
        Map<String, dynamic>.from(m['bakery'] as Map),
      );
    }
    return PublicProfileDetail(
      header: header,
      worker: worker,
      experiences: experiences,
      bakery: bakery,
    );
  }
}
