import 'package:firin_defter/features/social_groups/models/group_category.dart';
import 'package:firin_defter/features/social_groups/repositories/local_social_group_repository.dart';
import 'package:firin_defter/features/social_groups/services/group_join_result.dart';
import 'package:firin_defter/features/social_groups/services/group_validator.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('GroupValidator', () {
    const v = GroupValidator();

    test('grup oluşturma — boş isim hata', () {
      expect(v.validateName(''), isNotNull);
      expect(v.validateName('  '), isNotNull);
      expect(v.validateName('A'), isNotNull); // çok kısa
      expect(v.validateName('Konya Fırıncıları'), isNull);
    });

    test('grup oluşturma — boş açıklama hata', () {
      expect(v.validateDescription(''), isNotNull);
      expect(v.validateDescription('Bir grup hakkında'), isNull);
    });

    test('grup oluşturma — limit 5\'ten küçükse hata', () {
      expect(v.validateLimit(0), isNotNull);
      expect(v.validateLimit(4), isNotNull);
      expect(v.validateLimit(5), isNull);
      expect(v.validateLimit(100), isNull);
      expect(v.validateLimit(null), isNull); // sınırsız
    });
  });

  group('LocalSocialGroupRepository', () {
    test('limit dolduysa join engellenir (full)', () async {
      final repo = LocalSocialGroupRepository(seed: true);
      // Seed'de g_taşfırın 100/100 dolu.
      final g = await repo.getGroup('g_taşfırın');
      expect(g!.isFull, isTrue);

      final result = await repo.joinGroup('g_taşfırın');
      expect(result, GroupJoinResult.full);

      final after = await repo.getGroup('g_taşfırın');
      expect(after!.currentMemberCount, 100); // değişmedi
    });

    test('limit dolmadıysa join currentMemberCount\'u artırır', () async {
      final repo = LocalSocialGroupRepository(seed: true);
      // Seed'de g_bayi_dagitim 67/100.
      final before = await repo.getGroup('g_bayi_dagitim');
      expect(before!.currentMemberCount, 67);

      final r = await repo.joinGroup('g_bayi_dagitim');
      expect(r, GroupJoinResult.success);

      final after = await repo.getGroup('g_bayi_dagitim');
      expect(after!.currentMemberCount, 68);
      expect(repo.isJoined('g_bayi_dagitim'), isTrue);
    });

    test('zaten üye olan tekrar joinleyemez', () async {
      final repo = LocalSocialGroupRepository(seed: true);
      // Seed'de _joined zaten g_eksi_maya barındırıyor.
      final r = await repo.joinGroup('g_eksi_maya');
      expect(r, GroupJoinResult.alreadyJoined);
    });

    test('leave currentMemberCount\'u azaltır ve üyelikten çıkarır', () async {
      final repo = LocalSocialGroupRepository(seed: true);
      // g_eksi_maya 84/100, kullanıcı zaten üye.
      final before = await repo.getGroup('g_eksi_maya');
      expect(before!.currentMemberCount, 84);
      expect(repo.isJoined('g_eksi_maya'), isTrue);

      await repo.leaveGroup('g_eksi_maya');

      final after = await repo.getGroup('g_eksi_maya');
      expect(after!.currentMemberCount, 83);
      expect(repo.isJoined('g_eksi_maya'), isFalse);
    });

    test('unlimited grup hiçbir zaman dolu sayılmaz', () async {
      final repo = LocalSocialGroupRepository(seed: true);
      // g_ekipman_alımsatım maxMembers=null
      final g = await repo.getGroup('g_ekipman_alımsatım');
      expect(g!.maxMembers, isNull);
      expect(g.isUnlimited, isTrue);
      expect(g.isFull, isFalse);

      final r = await repo.joinGroup('g_ekipman_alımsatım');
      expect(r, GroupJoinResult.success);
    });

    test('category filter doğru çalışır', () async {
      final repo = LocalSocialGroupRepository(seed: true);
      final regional =
          await repo.listGroups(category: GroupCategory.regional);
      // Seed: g_konya_unciler + g_istanbul_pastane = 2
      expect(regional.length, 2);
      expect(regional.every((g) => g.category == GroupCategory.regional),
          isTrue);

      final equipment =
          await repo.listGroups(category: GroupCategory.equipment);
      expect(equipment.length, 1); // sadece g_ekipman_alımsatım
    });

    test('joined groups doğru listelenir', () async {
      final repo = LocalSocialGroupRepository(seed: true);
      // Seed: g_eksi_maya + g_un_tip550
      var joined = await repo.listJoined();
      expect(joined.length, 2);
      expect(joined.map((g) => g.id).toSet(),
          {'g_eksi_maya', 'g_un_tip550'});

      // Yeni gruba katıl + tekrar listele
      await repo.joinGroup('g_bayi_dagitim');
      joined = await repo.listJoined();
      expect(joined.length, 3);
      expect(joined.any((g) => g.id == 'g_bayi_dagitim'), isTrue);

      // Ayrılınca listeden düşmeli
      await repo.leaveGroup('g_eksi_maya');
      joined = await repo.listJoined();
      expect(joined.length, 2);
      expect(joined.any((g) => g.id == 'g_eksi_maya'), isFalse);
    });

    test('createGroup yeni grubu listeye ekler ve owner\'ı joined yapar',
        () async {
      final repo = LocalSocialGroupRepository(seed: false);
      final g = await repo.createGroup(
        name: 'Test Grubu',
        description: 'kısa bir açıklama',
        category: GroupCategory.bakers,
        maxMembers: 50,
      );
      expect(g.currentMemberCount, 1);
      expect(repo.isJoined(g.id), isTrue);

      final all = await repo.listGroups();
      expect(all.length, 1);
      expect(all.first.name, 'Test Grubu');
    });
  });
}
