/// FırınNet — `job_offer_posts` ("Usta Arıyor / İş Veriyorum") modeli.
///
/// Supabase tablosu: `job_offer_posts` (V1, migration 20260516092824).
/// RLS: authenticated select active veya owner; owner CRUD.
class JobOfferPost {
  const JobOfferPost({
    this.id,
    this.ownerId,
    this.bakeryId,
    required this.title,
    required this.roleTitle,
    this.city,
    this.district,
    this.cityCode,
    this.districtCode,
    this.description,
    this.salaryMin,
    this.salaryMax,
    this.shiftType,
    this.experienceRequired,
    this.roleCode,
    this.shiftCode,
    this.experienceCode,
    this.isActive = true,
    this.contactPreference = 'in_app',
    this.contactPhone,
    this.authorName,
    this.authorRole,
    this.createdAt,
    this.updatedAt,
    this.feeStatus = 'not_required',
    this.expiresAt,
  });

  final String? id;
  final String? ownerId;
  final String? bakeryId;
  final String title;
  final String roleTitle;

  /// Türkçe il label (eski text, display fallback).
  final String? city;

  /// Türkçe ilçe label (eski text, display fallback).
  final String? district;

  /// M6B — Türkiye plaka kodu (`34`, ...). Dual-write.
  final String? cityCode;

  /// M6B — İlçe ASCII slug. cityCode varsa set edilebilir.
  final String? districtCode;

  final String? description;
  final double? salaryMin;
  final double? salaryMax;

  /// Türkçe vardiya label (eski text, display fallback).
  final String? shiftType;

  /// Türkçe deneyim metni (eski text, display fallback). "min 3 yıl" gibi.
  final String? experienceRequired;

  /// M8 — ASCII profession code (M5 taxonomy ile birebir).
  final String? roleCode;

  /// M8 — ASCII shift code (`gunduz`/`gece`/`vardiyali`/`esnek`).
  final String? shiftCode;

  /// M8 — ASCII experience bracket (`none`/`0_2`/`3_5`/`5_plus`).
  final String? experienceCode;

  final bool isActive;
  final String contactPreference;

  /// Opsiyonel telefon numarası — sahibinin rızasıyla ilanda public görünür.
  /// Doğrulama YOK. Boşsa ilanda "Ara" butonu görünmez.
  final String? contactPhone;

  final String? authorName;
  final String? authorRole;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  /// İlan Ücretlendirme V1 — server-side set edilir (client değiştiremez).
  /// `not_required | pending | paid | waived | grandfathered`.
  final String feeStatus;
  final DateTime? expiresAt;

  /// Ücretli ilan ödeme bekliyor mu? (owner kendi ilanında görür; public'e
  /// pending ilan zaten görünmez — server SELECT gate'i.)
  bool get isPendingPayment => feeStatus == 'pending';

  JobOfferPost copyWith({
    String? title,
    String? roleTitle,
    String? city,
    String? district,
    String? cityCode,
    String? districtCode,
    String? description,
    double? salaryMin,
    double? salaryMax,
    String? shiftType,
    String? experienceRequired,
    String? roleCode,
    String? shiftCode,
    String? experienceCode,
    bool? isActive,
    String? contactPreference,
    String? contactPhone,
  }) {
    return JobOfferPost(
      id: id,
      ownerId: ownerId,
      bakeryId: bakeryId,
      title: title ?? this.title,
      roleTitle: roleTitle ?? this.roleTitle,
      city: city ?? this.city,
      district: district ?? this.district,
      cityCode: cityCode ?? this.cityCode,
      districtCode: districtCode ?? this.districtCode,
      description: description ?? this.description,
      salaryMin: salaryMin ?? this.salaryMin,
      salaryMax: salaryMax ?? this.salaryMax,
      shiftType: shiftType ?? this.shiftType,
      experienceRequired: experienceRequired ?? this.experienceRequired,
      roleCode: roleCode ?? this.roleCode,
      shiftCode: shiftCode ?? this.shiftCode,
      experienceCode: experienceCode ?? this.experienceCode,
      isActive: isActive ?? this.isActive,
      contactPreference: contactPreference ?? this.contactPreference,
      contactPhone: contactPhone ?? this.contactPhone,
      authorName: authorName,
      authorRole: authorRole,
      createdAt: createdAt,
      updatedAt: updatedAt,
      feeStatus: feeStatus,
      expiresAt: expiresAt,
    );
  }

  Map<String, dynamic> toInsertRow(String ownerId) {
    return <String, dynamic>{
      'owner_id': ownerId,
      if (bakeryId != null) 'bakery_id': bakeryId,
      'title': title,
      'role_title': roleTitle,
      if (city != null && city!.trim().isNotEmpty) 'city': city,
      if (district != null && district!.trim().isNotEmpty) 'district': district,
      if (cityCode != null && cityCode!.isNotEmpty) 'city_code': cityCode,
      if (districtCode != null && districtCode!.isNotEmpty)
        'district_code': districtCode,
      if (description != null && description!.trim().isNotEmpty)
        'description': description,
      if (salaryMin != null) 'salary_min': salaryMin,
      if (salaryMax != null) 'salary_max': salaryMax,
      if (shiftType != null && shiftType!.trim().isNotEmpty)
        'shift_type': shiftType,
      if (experienceRequired != null && experienceRequired!.trim().isNotEmpty)
        'experience_required': experienceRequired,
      if (roleCode != null && roleCode!.isNotEmpty) 'role_code': roleCode,
      if (shiftCode != null && shiftCode!.isNotEmpty) 'shift_code': shiftCode,
      if (experienceCode != null && experienceCode!.isNotEmpty)
        'experience_code': experienceCode,
      'is_active': isActive,
      'contact_preference': contactPreference,
      if (contactPhone != null && contactPhone!.trim().isNotEmpty)
        'contact_phone': contactPhone!.trim(),
    };
  }

  factory JobOfferPost.fromRow(Map<String, dynamic> row) {
    DateTime? parse(String? s) => s == null ? null : DateTime.tryParse(s);
    return JobOfferPost(
      id: row['id'] as String?,
      ownerId: row['owner_id'] as String?,
      bakeryId: row['bakery_id'] as String?,
      title: (row['title'] as String?) ?? '',
      roleTitle: (row['role_title'] as String?) ?? '',
      city: row['city'] as String?,
      district: row['district'] as String?,
      cityCode: row['city_code'] as String?,
      districtCode: row['district_code'] as String?,
      description: row['description'] as String?,
      salaryMin: (row['salary_min'] as num?)?.toDouble(),
      salaryMax: (row['salary_max'] as num?)?.toDouble(),
      shiftType: row['shift_type'] as String?,
      experienceRequired: row['experience_required'] as String?,
      roleCode: row['role_code'] as String?,
      shiftCode: row['shift_code'] as String?,
      experienceCode: row['experience_code'] as String?,
      isActive: (row['is_active'] as bool?) ?? true,
      contactPreference: (row['contact_preference'] as String?) ?? 'in_app',
      contactPhone: row['contact_phone'] as String?,
      authorName: row['author_name'] as String?,
      authorRole: row['author_role'] as String?,
      createdAt: parse(row['created_at'] as String?),
      updatedAt: parse(row['updated_at'] as String?),
      feeStatus: (row['fee_status'] as String?) ?? 'not_required',
      expiresAt: parse(row['expires_at'] as String?),
    );
  }
}
