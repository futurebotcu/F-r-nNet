/// Bireysel kullanıcının ustalık profili.
///
/// Supabase tablosu: `worker_profiles` (V1.2). Kullanıcı başına bir kayıt
/// (`owner_id` unique). Diğer authenticated kullanıcılar okuyabilir
/// (sektör profili), düzenleme yalnız sahibine açıktır (RLS).
class WorkerProfile {
  const WorkerProfile({
    this.id,
    this.ownerId,
    this.professionBadge,
    this.professionBadgeCode,
    this.experienceYears,
    this.cities = const <String>[],
    this.shiftPreference,
    this.salaryExpectation,
    this.workType,
    this.skills = const <String>[],
    this.bio,
    this.createdAt,
    this.updatedAt,
  });

  final String? id;
  final String? ownerId;

  /// Usta fırıncı, mayacı, hamurcu, simitçi, poğaçacı, pasta ustası, çırak,
  /// kalfa vb. Türkçe label (display fallback, backward compat).
  final String? professionBadge;

  /// M5 — ASCII code (`usta_firinci`, `mayaci`, vb.). Yeni yazılan kayıtlarda
  /// dual-write yapılır. UI önce code'u tüketir, yoksa [professionBadge]
  /// label'ına düşer.
  final String? professionBadgeCode;

  final int? experienceYears;
  final List<String> cities;

  /// gunduz / gece / vardiyali / esnek
  final String? shiftPreference;

  final double? salaryExpectation;

  /// tam_zamanli / part_time / sezonluk
  final String? workType;

  final List<String> skills;
  final String? bio;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  bool get isEmpty =>
      (professionBadge == null || professionBadge!.isEmpty) &&
      experienceYears == null &&
      cities.isEmpty &&
      (shiftPreference == null || shiftPreference!.isEmpty) &&
      salaryExpectation == null &&
      (workType == null || workType!.isEmpty) &&
      skills.isEmpty &&
      (bio == null || bio!.isEmpty);

  WorkerProfile copyWith({
    String? id,
    String? ownerId,
    String? professionBadge,
    String? professionBadgeCode,
    int? experienceYears,
    List<String>? cities,
    String? shiftPreference,
    double? salaryExpectation,
    String? workType,
    List<String>? skills,
    String? bio,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return WorkerProfile(
      id: id ?? this.id,
      ownerId: ownerId ?? this.ownerId,
      professionBadge: professionBadge ?? this.professionBadge,
      professionBadgeCode: professionBadgeCode ?? this.professionBadgeCode,
      experienceYears: experienceYears ?? this.experienceYears,
      cities: cities ?? this.cities,
      shiftPreference: shiftPreference ?? this.shiftPreference,
      salaryExpectation: salaryExpectation ?? this.salaryExpectation,
      workType: workType ?? this.workType,
      skills: skills ?? this.skills,
      bio: bio ?? this.bio,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toInsertRow(String ownerId) => <String, dynamic>{
        'owner_id': ownerId,
        if (professionBadge != null && professionBadge!.isNotEmpty)
          'profession_badge': professionBadge,
        if (professionBadgeCode != null && professionBadgeCode!.isNotEmpty)
          'profession_badge_code': professionBadgeCode,
        if (experienceYears != null) 'experience_years': experienceYears,
        'cities': cities,
        if (shiftPreference != null && shiftPreference!.isNotEmpty)
          'shift_preference': shiftPreference,
        if (salaryExpectation != null) 'salary_expectation': salaryExpectation,
        if (workType != null && workType!.isNotEmpty) 'work_type': workType,
        'skills': skills,
        if (bio != null && bio!.isNotEmpty) 'bio': bio,
      };

  factory WorkerProfile.fromRow(Map<String, dynamic> row) {
    return WorkerProfile(
      id: row['id'] as String?,
      ownerId: row['owner_id'] as String?,
      professionBadge: row['profession_badge'] as String?,
      professionBadgeCode: row['profession_badge_code'] as String?,
      experienceYears: (row['experience_years'] as num?)?.toInt(),
      cities: (row['cities'] as List?)?.cast<String>() ?? const <String>[],
      shiftPreference: row['shift_preference'] as String?,
      salaryExpectation: (row['salary_expectation'] as num?)?.toDouble(),
      workType: row['work_type'] as String?,
      skills: (row['skills'] as List?)?.cast<String>() ?? const <String>[],
      bio: row['bio'] as String?,
      createdAt: row['created_at'] != null
          ? DateTime.parse(row['created_at'] as String)
          : null,
      updatedAt: row['updated_at'] != null
          ? DateTime.parse(row['updated_at'] as String)
          : null,
    );
  }
}

class WorkerExperience {
  const WorkerExperience({
    this.id,
    this.ownerId,
    required this.title,
    this.workplace,
    this.city,
    this.startDate,
    this.endDate,
    this.description,
    this.createdAt,
  });

  final String? id;
  final String? ownerId;
  final String title;
  final String? workplace;
  final String? city;
  final DateTime? startDate;
  final DateTime? endDate;
  final String? description;
  final DateTime? createdAt;

  WorkerExperience copyWith({
    String? id,
    String? ownerId,
    String? title,
    String? workplace,
    String? city,
    DateTime? startDate,
    DateTime? endDate,
    String? description,
    DateTime? createdAt,
  }) {
    return WorkerExperience(
      id: id ?? this.id,
      ownerId: ownerId ?? this.ownerId,
      title: title ?? this.title,
      workplace: workplace ?? this.workplace,
      city: city ?? this.city,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      description: description ?? this.description,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toInsertRow(String ownerId) {
    String? d(DateTime? x) {
      if (x == null) return null;
      final mm = x.month.toString().padLeft(2, '0');
      final dd = x.day.toString().padLeft(2, '0');
      return '${x.year}-$mm-$dd';
    }

    return <String, dynamic>{
      'owner_id': ownerId,
      'title': title,
      if (workplace != null && workplace!.isNotEmpty) 'workplace': workplace,
      if (city != null && city!.isNotEmpty) 'city': city,
      if (startDate != null) 'start_date': d(startDate),
      if (endDate != null) 'end_date': d(endDate),
      if (description != null && description!.isNotEmpty)
        'description': description,
    };
  }

  factory WorkerExperience.fromRow(Map<String, dynamic> row) {
    DateTime? p(String? s) => s == null ? null : DateTime.tryParse(s);
    return WorkerExperience(
      id: row['id'] as String?,
      ownerId: row['owner_id'] as String?,
      title: (row['title'] as String?) ?? '',
      workplace: row['workplace'] as String?,
      city: row['city'] as String?,
      startDate: p(row['start_date'] as String?),
      endDate: p(row['end_date'] as String?),
      description: row['description'] as String?,
      createdAt: p(row['created_at'] as String?),
    );
  }
}
