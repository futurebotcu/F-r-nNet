/// "İş arıyorum" ilanı.
///
/// Supabase tablosu: `job_seek_posts` (V1.2). Aktifse authenticated read açık;
/// edit owner-only (RLS).
class JobSeekPost {
  const JobSeekPost({
    this.id,
    this.ownerId,
    required this.title,
    this.professionBadge,
    this.professionBadgeCode,
    this.city,
    this.cityCode,
    this.experienceYears,
    this.salaryExpectation,
    this.description,
    this.isActive = true,
    this.contactPhone,
    this.contactPreference = 'in_app',
    this.createdAt,
    this.updatedAt,
  });

  final String? id;
  final String? ownerId;
  final String title;

  /// Türkçe label (display fallback, backward compat).
  final String? professionBadge;

  /// M5 — ASCII code (`usta_firinci`, `mayaci`, ...). Yeni yazılan kayıtlarda
  /// dual-write yapılır.
  final String? professionBadgeCode;

  /// Türkçe il adı (eski text, display fallback).
  final String? city;

  /// M6A — Türkiye plaka kodu (`34`, ...). Dual-write.
  final String? cityCode;

  final int? experienceYears;
  final double? salaryExpectation;
  final String? description;
  final bool isActive;

  /// Opsiyonel telefon — sahibinin rızasıyla ilanda public görünür.
  /// Doğrulama yok. Boşsa ilanda "Ara" butonu görünmez.
  final String? contactPhone;

  /// `in_app` (default) / `phone` / `whatsapp`. M6B migration sonrası
  /// DB CHECK ile sınırlandırılmış.
  final String contactPreference;

  final DateTime? createdAt;
  final DateTime? updatedAt;

  JobSeekPost copyWith({
    String? id,
    String? ownerId,
    String? title,
    String? professionBadge,
    String? professionBadgeCode,
    String? city,
    String? cityCode,
    int? experienceYears,
    double? salaryExpectation,
    String? description,
    bool? isActive,
    String? contactPhone,
    String? contactPreference,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return JobSeekPost(
      id: id ?? this.id,
      ownerId: ownerId ?? this.ownerId,
      title: title ?? this.title,
      professionBadge: professionBadge ?? this.professionBadge,
      professionBadgeCode: professionBadgeCode ?? this.professionBadgeCode,
      city: city ?? this.city,
      cityCode: cityCode ?? this.cityCode,
      experienceYears: experienceYears ?? this.experienceYears,
      salaryExpectation: salaryExpectation ?? this.salaryExpectation,
      description: description ?? this.description,
      isActive: isActive ?? this.isActive,
      contactPhone: contactPhone ?? this.contactPhone,
      contactPreference: contactPreference ?? this.contactPreference,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toInsertRow(String ownerId) => <String, dynamic>{
        'owner_id': ownerId,
        'title': title,
        if (professionBadge != null && professionBadge!.isNotEmpty)
          'profession_badge': professionBadge,
        if (professionBadgeCode != null && professionBadgeCode!.isNotEmpty)
          'profession_badge_code': professionBadgeCode,
        if (city != null && city!.isNotEmpty) 'city': city,
        if (cityCode != null && cityCode!.isNotEmpty) 'city_code': cityCode,
        if (experienceYears != null) 'experience_years': experienceYears,
        if (salaryExpectation != null) 'salary_expectation': salaryExpectation,
        if (description != null && description!.isNotEmpty)
          'description': description,
        'is_active': isActive,
        if (contactPhone != null && contactPhone!.trim().isNotEmpty)
          'contact_phone': contactPhone!.trim(),
        'contact_preference': contactPreference,
      };

  factory JobSeekPost.fromRow(Map<String, dynamic> row) {
    DateTime? p(String? s) => s == null ? null : DateTime.tryParse(s);
    return JobSeekPost(
      id: row['id'] as String?,
      ownerId: row['owner_id'] as String?,
      title: (row['title'] as String?) ?? '',
      professionBadge: row['profession_badge'] as String?,
      professionBadgeCode: row['profession_badge_code'] as String?,
      city: row['city'] as String?,
      cityCode: row['city_code'] as String?,
      experienceYears: (row['experience_years'] as num?)?.toInt(),
      salaryExpectation: (row['salary_expectation'] as num?)?.toDouble(),
      description: row['description'] as String?,
      isActive: (row['is_active'] as bool?) ?? true,
      contactPhone: row['contact_phone'] as String?,
      contactPreference:
          (row['contact_preference'] as String?) ?? 'in_app',
      createdAt: p(row['created_at'] as String?),
      updatedAt: p(row['updated_at'] as String?),
    );
  }

  /// WhatsApp / sistem paylaşımı için saf metin builder.
  String toShareText() {
    final lines = <String>[];
    lines.add('$title — İş Arıyorum');
    if (professionBadge != null && professionBadge!.isNotEmpty) {
      lines.add('Meslek: $professionBadge');
    }
    if (city != null && city!.isNotEmpty) {
      lines.add('Şehir: $city');
    }
    if (experienceYears != null) {
      lines.add('Tecrübe: $experienceYears yıl');
    }
    if (salaryExpectation != null) {
      lines.add('Maaş beklentisi: ${salaryExpectation!.toStringAsFixed(0)} TL');
    }
    if (description != null && description!.isNotEmpty) {
      lines.add('');
      lines.add(description!);
    }
    lines.add('');
    lines.add('FırınNet');
    return lines.join('\n');
  }
}
