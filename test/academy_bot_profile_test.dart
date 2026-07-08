import 'package:firin_defter/features/academy/models/academy_bot_profile.dart';
import 'package:flutter_test/flutter_test.dart';

/// FırınNet Akademi Bot Profil Altyapısı V1 (PR A1) — model/parse testleri.
/// Asıl güvenlik server-side RLS (canlı smoke PASS): user bot profili
/// oluşturamaz / başka owner_id ile post atamaz; bot postu yalnız service_role.
void main() {
  group('AcademyTopic taksonomi', () {
    test('persistKey round-trip + fuar_sektor eşlemesi', () {
      for (final t in AcademyTopic.values) {
        expect(AcademyTopicMeta.fromKey(t.persistKey), t);
      }
      expect(AcademyTopic.fuarSektor.persistKey, 'fuar_sektor');
      expect(AcademyTopicMeta.fromKey('fuar_sektor'), AcademyTopic.fuarSektor);
    });

    test('bilinmeyen key → akademi (güvenli default)', () {
      expect(AcademyTopicMeta.fromKey(null), AcademyTopic.akademi);
      expect(AcademyTopicMeta.fromKey('bilinmeyen'), AcademyTopic.akademi);
    });

    test('11 konu + label', () {
      expect(AcademyTopic.values.length, 11);
      expect(AcademyTopic.fuarSektor.label, 'Fuar & Sektör');
      expect(AcademyTopic.maliyet.label, 'Maliyet');
    });
  });

  group('AcademyBotProfile.fromRow', () {
    test('tam satır eşlenir', () {
      final b = AcademyBotProfile.fromRow(<String, dynamic>{
        'profile_id': 'p1',
        'bot_key': 'akademi',
        'topic': 'akademi',
        'bio': 'Sektör içgörüleri',
        'is_active': true,
        'is_visible': true,
        'posting_enabled': true,
        'daily_post_limit': 1,
      });
      expect(b.profileId, 'p1');
      expect(b.botKey, 'akademi');
      expect(b.topic, AcademyTopic.akademi);
      expect(b.bio, 'Sektör içgörüleri');
      expect(b.dailyPostLimit, 1);
      expect(b.unlimitedDaily, isFalse);
    });

    test('eksik satır → güvenli defaultlar', () {
      final b = AcademyBotProfile.fromRow(<String, dynamic>{});
      expect(b.botKey, '');
      expect(b.topic, AcademyTopic.akademi);
      expect(b.isActive, isTrue);
      expect(b.isVisible, isTrue);
      expect(b.dailyPostLimit, 1);
    });

    test('daily_post_limit 0 → sınırsız', () {
      final b = AcademyBotProfile.fromRow(<String, dynamic>{
        'profile_id': 'p',
        'bot_key': 'x',
        'topic': 'haber',
        'daily_post_limit': 0,
      });
      expect(b.unlimitedDaily, isTrue);
      expect(b.topic, AcademyTopic.haber);
    });
  });
}
