// FırınNet V1 Unified Profile M2 — public_profile_detail RPC modeli.
//
// Migration: 20260520170000_unified_profile_public_rpc.sql
// RPC `public_profile_detail(uuid) returns jsonb` whitelisted aggregate
// veri döner. salary_expectation, email, phone gibi hassas alanlar
// RPC tarafında dahi seçilmez. Bu model yalnız UI render için.

class PublicProfileHeader {
  const PublicProfileHeader({
    required this.id,
    this.displayName,
    this.avatarUrl,
    this.accountType,
    this.professionBadge,
    this.city,
  });

  final String id;
  final String? displayName;
  final String? avatarUrl;

  /// `commercial` | `individual` | `wholesaler` (profiles.account_type)
  final String? accountType;

  /// V1: profiles.profession_badge fallback; worker varsa worker öncelikli.
  /// `PublicProfileDetail.effectiveProfessionBadge` ile çözülür.
  final String? professionBadge;

  final String? city;

  static PublicProfileHeader fromJson(Map<String, dynamic> j) {
    return PublicProfileHeader(
      id: j['id'] as String,
      displayName: j['display_name'] as String?,
      avatarUrl: j['avatar_url'] as String?,
      accountType: j['account_type'] as String?,
      professionBadge: j['profession_badge'] as String?,
      city: j['city'] as String?,
    );
  }
}

class PublicWorkerInfo {
  const PublicWorkerInfo({
    this.professionBadge,
    this.experienceYears,
    this.cities = const <String>[],
    this.skills = const <String>[],
    this.shiftPreference,
    this.bio,
  });

  final String? professionBadge;
  final int? experienceYears;
  final List<String> cities;
  final List<String> skills;
  final String? shiftPreference;
  final String? bio;

  bool get isEmpty =>
      (professionBadge == null || professionBadge!.isEmpty) &&
      experienceYears == null &&
      cities.isEmpty &&
      skills.isEmpty &&
      (shiftPreference == null || shiftPreference!.isEmpty) &&
      (bio == null || bio!.isEmpty);

  static PublicWorkerInfo fromJson(Map<String, dynamic> j) {
    List<String> asStringList(dynamic v) {
      if (v is List) {
        return v.whereType<String>().toList(growable: false);
      }
      return const <String>[];
    }

    return PublicWorkerInfo(
      professionBadge: j['profession_badge'] as String?,
      experienceYears: (j['experience_years'] as num?)?.toInt(),
      cities: asStringList(j['cities']),
      skills: asStringList(j['skills']),
      shiftPreference: j['shift_preference'] as String?,
      bio: j['bio'] as String?,
    );
  }
}

class PublicWorkerExperience {
  const PublicWorkerExperience({
    required this.id,
    required this.title,
    this.city,
    this.startDate,
    this.endDate,
    this.description,
  });

  final String id;
  final String title;
  final String? city;
  final DateTime? startDate;
  final DateTime? endDate;
  final String? description;

  bool get isCurrent => endDate == null && startDate != null;

  static PublicWorkerExperience fromJson(Map<String, dynamic> j) {
    DateTime? parse(String? s) =>
        s == null ? null : DateTime.tryParse(s);
    return PublicWorkerExperience(
      id: j['id'] as String,
      title: (j['title'] as String?) ?? '',
      city: j['city'] as String?,
      startDate: parse(j['start_date'] as String?),
      endDate: parse(j['end_date'] as String?),
      description: j['description'] as String?,
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

  /// V1 fallback: worker.profession_badge öncelikli, yoksa profile fallback.
  String? get effectiveProfessionBadge {
    final w = worker?.professionBadge;
    if (w != null && w.isNotEmpty) return w;
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
          experiences.add(PublicWorkerExperience.fromJson(
            Map<String, dynamic>.from(e),
          ));
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
