import 'package:supabase_flutter/supabase_flutter.dart' as sb;

import '../models/partner_business.dart';
import '../models/partner_business_application.dart';
import 'partner_business_repository.dart';

/// Supabase Anlaşmalı İş Yerleri reposu.
///
/// Liste: RLS zaten yalnız is_active=true döndürür; yine de sorguda filtre
/// açıkça tekrarlanır (savunma katmanı + niyet okunurluğu). Başvuru:
/// create_partner_business_application RPC'si (requester_id server-side),
/// ardından send-partner-business-application-email edge function'ı
/// best-effort çağrılır — mail hatası kullanıcı akışını KIRMAZ.
class SupabasePartnerBusinessRepository implements PartnerBusinessRepository {
  SupabasePartnerBusinessRepository(this._client);

  final sb.SupabaseClient _client;

  @override
  Future<List<PartnerBusiness>> activePartners({int limit = 50}) async {
    final rows = await _client
        .from('partner_businesses')
        .select(
          'id, name, category, city, district, address, phone, email, '
          'website_url, map_url, benefit_summary, description, logo_url, '
          'sort_order',
        )
        .eq('is_active', true)
        .order('sort_order')
        .order('name')
        .limit(limit);
    return (rows as List)
        .cast<Map<String, dynamic>>()
        .map(PartnerBusiness.fromRow)
        .toList(growable: false);
  }

  @override
  Future<PartnerBusiness?> partnerById(String id) async {
    final rows = await _client
        .from('partner_businesses')
        .select(
          'id, name, category, city, district, address, phone, email, '
          'website_url, map_url, benefit_summary, description, logo_url, '
          'sort_order',
        )
        .eq('id', id)
        .eq('is_active', true)
        .limit(1);
    final list = (rows as List).cast<Map<String, dynamic>>();
    if (list.isEmpty) return null;
    return PartnerBusiness.fromRow(list.first);
  }

  @override
  Future<String> submitApplication(
    PartnerBusinessApplicationDraft draft,
  ) async {
    final String id;
    try {
      final result = await _client.rpc(
        'create_partner_business_application',
        params: <String, dynamic>{
          'p_business_name': draft.businessName.trim(),
          'p_contact_name': draft.contactName.trim(),
          'p_phone': draft.phone.trim(),
          'p_city': draft.city.trim(),
          'p_district': draft.district.trim(),
          'p_category': draft.category.trim(),
          if (draft.email.trim().isNotEmpty) 'p_email': draft.email.trim(),
          if (draft.message.trim().isNotEmpty)
            'p_message': draft.message.trim(),
        },
      );
      id = result as String;
    } on sb.PostgrestException catch (e) {
      if (e.message.contains('too many applications')) {
        throw StateError(
          'Kısa sürede çok fazla başvuru yaptın. Lütfen daha sonra dene.',
        );
      }
      throw StateError('Başvuru gönderilemedi. Tekrar dene.');
    }
    // Destek maili best-effort: env/provider yoksa veya çağrı düşerse
    // başvuru YİNE başarılıdır (kullanıcıya hata gösterilmez).
    try {
      await _client.functions.invoke(
        'send-partner-business-application-email',
        body: <String, dynamic>{'application_id': id},
      );
    } catch (_) {
      // yut — email_not_configured / ağ hatası akışı bozmaz.
    }
    return id;
  }
}
