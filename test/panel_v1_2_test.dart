import 'package:firin_defter/app/router/app_router.dart';
import 'package:firin_defter/features/dashboard/services/role_panel_cards.dart';
import 'package:firin_defter/features/dealers/models/dealer.dart';
import 'package:firin_defter/features/dealers/models/dealer_note.dart';
import 'package:firin_defter/features/dealers/models/dealer_price.dart';
import 'package:firin_defter/features/dealers/models/dealer_transaction.dart';
import 'package:firin_defter/features/dealers/repositories/local_dealer_repository.dart';
import 'package:firin_defter/features/profile/models/bakery_profile.dart';
import 'package:firin_defter/features/worker/models/job_seek_post.dart';
import 'package:firin_defter/features/worker/models/worker_profile.dart';
import 'package:firin_defter/features/worker/repositories/local_worker_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('V1.2 — Role panel cards hiyerarşisi', () {
    test('Ticari panelde Fırın Paneli + Bayi Paneli + Hesaplama + Reçeteler', () {
      final cards = RolePanelCards.forAccount(AccountType.commercial);
      final routes = cards.map((c) => c.route).toList();

      // Ana modüller ilk iki sırada
      expect(cards[0].route, AppRoutes.bakeryPanel);
      expect(cards[1].route, AppRoutes.dealers);

      // Hesaplama Makinesi ayrı kart olarak var
      expect(routes, contains(AppRoutes.calculator));
      // Reçetelerim ayrı kart olarak var
      expect(routes, contains(AppRoutes.recipes));

      // İlanlarım (jobs) destekte
      expect(routes, contains(AppRoutes.jobs));
    });

    test('Bireysel panelde İş Arıyorum + Ustalık + Tecrübe + Hesaplama + Reçete',
        () {
      final cards = RolePanelCards.forAccount(AccountType.individual);
      final routes = cards.map((c) => c.route).whereType<String>().toList();

      expect(routes, contains(AppRoutes.jobSeek));
      expect(routes, contains(AppRoutes.workerProfile));
      expect(routes, contains(AppRoutes.workerExperiences));
      expect(routes, contains(AppRoutes.calculator));
      expect(routes, contains(AppRoutes.recipes));
      expect(routes, contains(AppRoutes.profile));
    });

    test('Toptancı panelde Müşteriler kartı /wholesale/customers route\'una gider',
        () {
      final cards = RolePanelCards.forAccount(AccountType.wholesaler);
      final routes = cards.map((c) => c.route).whereType<String>().toList();
      expect(routes, contains(AppRoutes.wholesaleCustomers));
    });

    test('comingSoon kartların route\'u null', () {
      for (final t in AccountType.values) {
        final cards = RolePanelCards.forAccount(t);
        for (final c in cards) {
          if (c.comingSoon) expect(c.route, isNull);
        }
      }
    });
  });

  group('V1.2 — Dealer model customer_type', () {
    test('default customer_type = bakery_dealer', () {
      final d = Dealer(id: 'd1', name: 'X', createdAt: DateTime(2026, 5, 13));
      expect(d.customerType, DealerCustomerType.bakeryDealer);
      expect(d.customerType.persistKey, 'bakery_dealer');
    });

    test('persistKey round-trip', () {
      expect(
        DealerCustomerTypeLabel.fromPersistKey('wholesale_customer'),
        DealerCustomerType.wholesaleCustomer,
      );
      expect(
        DealerCustomerTypeLabel.fromPersistKey('bakery_dealer'),
        DealerCustomerType.bakeryDealer,
      );
      // Bilinmeyen → default bakery_dealer
      expect(
        DealerCustomerTypeLabel.fromPersistKey(null),
        DealerCustomerType.bakeryDealer,
      );
    });

    test('LocalDealerRepository customer_type filtresi (wholesale)', () async {
      final repo = LocalDealerRepository(seed: false);
      final now = DateTime.now();
      await repo.upsertDealer(Dealer(
        id: 'd_a',
        name: 'Bayi A',
        createdAt: now,
        customerType: DealerCustomerType.bakeryDealer,
      ));
      await repo.upsertDealer(Dealer(
        id: 'd_b',
        name: 'Müşteri B',
        createdAt: now,
        customerType: DealerCustomerType.wholesaleCustomer,
      ));

      final wholesale = await repo.listDealers(
          customerType: DealerCustomerType.wholesaleCustomer);
      expect(wholesale, hasLength(1));
      expect(wholesale.first.id, 'd_b');

      final bakery = await repo.listDealers(
          customerType: DealerCustomerType.bakeryDealer);
      expect(bakery, hasLength(1));
      expect(bakery.first.id, 'd_a');

      final all = await repo.listDealers();
      expect(all, hasLength(2));
    });
  });

  group('V1.2 — Dealer transactions / prices / notes (Local)', () {
    test('payment transaction LocalRepo\'da persist olur', () async {
      final repo = LocalDealerRepository(seed: false);
      await repo.upsertDealer(Dealer(
        id: 'd1',
        name: 'X',
        createdAt: DateTime(2026, 5, 13),
      ));
      await repo.addTransaction(DealerTransaction(
        id: 't1',
        dealerId: 'd1',
        type: DealerTransactionType.payment,
        amount: 500,
        paymentMethod: DealerPaymentMethod.cash,
        createdAt: DateTime(2026, 5, 13, 10),
      ));
      final txs = await repo.listTransactions('d1');
      expect(txs, hasLength(1));
      expect(txs.first.type, DealerTransactionType.payment);
      expect(txs.first.amount, 500);
    });

    test('return transaction LocalRepo\'da persist olur', () async {
      final repo = LocalDealerRepository(seed: false);
      await repo.addTransaction(DealerTransaction(
        id: 't1',
        dealerId: 'd1',
        type: DealerTransactionType.returned,
        productName: 'Ekmek',
        quantity: 6,
        amount: 51,
        createdAt: DateTime(2026, 5, 13),
      ));
      expect(
        DealerTransactionType.returned.persistKey,
        'return',
      );
      final txs = await repo.listTransactions('d1');
      expect(txs.first.type, DealerTransactionType.returned);
    });

    test('price added and current price retrieved', () async {
      final repo = LocalDealerRepository(seed: false);
      await repo.addPrice(DealerPrice(
        id: 'p1',
        dealerId: 'd1',
        productName: 'Ekmek',
        unitPrice: 8.5,
        validFrom: DateTime(2026, 5, 1),
      ));
      await repo.addPrice(DealerPrice(
        id: 'p2',
        dealerId: 'd1',
        productName: 'Ekmek',
        unitPrice: 9,
        validFrom: DateTime(2026, 5, 13),
      ));
      final cur =
          await repo.currentPriceFor(dealerId: 'd1', productName: 'Ekmek');
      expect(cur?.unitPrice, 9); // En son valid_from
    });

    test('note added and listed desc', () async {
      final repo = LocalDealerRepository(seed: false);
      await repo.addNote(DealerNote(
        id: 'n1',
        dealerId: 'd1',
        note: 'Eski not',
        createdAt: DateTime(2026, 5, 1),
      ));
      await repo.addNote(DealerNote(
        id: 'n2',
        dealerId: 'd1',
        note: 'Yeni not',
        createdAt: DateTime(2026, 5, 13),
      ));
      final notes = await repo.listNotes('d1');
      expect(notes.first.id, 'n2'); // desc by date
    });

    test('payment_method persistKey round-trip', () {
      for (final m in DealerPaymentMethod.values) {
        expect(
          DealerPaymentMethodLabel.fromPersistKey(m.persistKey),
          m,
        );
      }
    });
  });

  group('V1.2 — WorkerProfile model + mapping', () {
    test('toInsertRow başlık alanlarını DB sütun adına çevirir', () {
      const p = WorkerProfile(
        professionBadge: 'Usta Fırıncı',
        experienceYears: 7,
        cities: ['Manisa', 'İzmir'],
        shiftPreference: 'gunduz',
        salaryExpectation: 38000,
        workType: 'tam_zamanli',
        skills: ['taş fırın', 'ekşi maya'],
        bio: 'Manisa civarı',
      );
      final row = p.toInsertRow('u1');
      expect(row['owner_id'], 'u1');
      expect(row['profession_badge'], 'Usta Fırıncı');
      expect(row['experience_years'], 7);
      expect(row['cities'], ['Manisa', 'İzmir']);
      expect(row['shift_preference'], 'gunduz');
      expect(row['salary_expectation'], 38000);
      expect(row['work_type'], 'tam_zamanli');
      expect(row['skills'], ['taş fırın', 'ekşi maya']);
      expect(row['bio'], 'Manisa civarı');
    });

    test('fromRow tam round-trip', () {
      final restored = WorkerProfile.fromRow(<String, dynamic>{
        'id': 'w1',
        'owner_id': 'u1',
        'profession_badge': 'Mayacı',
        'experience_years': 5,
        'cities': <String>['Konya'],
        'shift_preference': 'gece',
        'salary_expectation': 30000,
        'work_type': 'part_time',
        'skills': <String>['levain'],
        'bio': 'Gece vardiyası',
        'created_at': '2026-05-13T09:00:00Z',
        'updated_at': '2026-05-13T10:00:00Z',
      });
      expect(restored.id, 'w1');
      expect(restored.professionBadge, 'Mayacı');
      expect(restored.experienceYears, 5);
      expect(restored.cities, <String>['Konya']);
      expect(restored.shiftPreference, 'gece');
      expect(restored.salaryExpectation, 30000);
      expect(restored.workType, 'part_time');
      expect(restored.skills, <String>['levain']);
      expect(restored.bio, 'Gece vardiyası');
    });

    test('LocalWorkerRepository upsert + read', () async {
      final repo = LocalWorkerRepository();
      expect(await repo.getMyProfile(), isNull);
      final saved = await repo.upsertMyProfile(const WorkerProfile(
        professionBadge: 'Çırak',
        experienceYears: 1,
      ));
      expect(saved.id, isNotNull);
      final read = await repo.getMyProfile();
      expect(read?.professionBadge, 'Çırak');
      // Upsert üzerine yazıyor mu?
      await repo.upsertMyProfile(saved.copyWith(experienceYears: 2));
      final read2 = await repo.getMyProfile();
      expect(read2?.experienceYears, 2);
    });
  });

  group('V1.2 — JobSeekPost model + mapping + share', () {
    test('toShareText brief örneği', () {
      const p = JobSeekPost(
        title: 'Manisa civarı fırıncı',
        professionBadge: 'Usta Fırıncı',
        city: 'Manisa',
        experienceYears: 7,
        salaryExpectation: 38000,
        description:
            'Manisa ve çevresinde gündüz vardiyası fırın işi arıyorum.',
      );
      final text = p.toShareText();
      expect(text, contains('Manisa civarı fırıncı — İş Arıyorum'));
      expect(text, contains('Meslek: Usta Fırıncı'));
      expect(text, contains('Şehir: Manisa'));
      expect(text, contains('Tecrübe: 7 yıl'));
      expect(text, contains('Maaş beklentisi: 38000 TL'));
      expect(text, endsWith('FırınNet'));
    });

    test('toInsertRow DB sütun adı eşlemesi', () {
      const p = JobSeekPost(
        title: 'X',
        professionBadge: 'Mayacı',
        city: 'İzmir',
        experienceYears: 3,
        salaryExpectation: 25000,
        description: 'Gece tercih',
        isActive: false,
      );
      final row = p.toInsertRow('u1');
      expect(row['owner_id'], 'u1');
      expect(row['title'], 'X');
      expect(row['profession_badge'], 'Mayacı');
      expect(row['city'], 'İzmir');
      expect(row['experience_years'], 3);
      expect(row['salary_expectation'], 25000);
      expect(row['description'], 'Gece tercih');
      expect(row['is_active'], false);
    });

    test('LocalWorkerRepository upsert/list/delete iş ilanı', () async {
      final repo = LocalWorkerRepository();
      final saved = await repo.upsertJobSeekPost(
        const JobSeekPost(title: 'A'),
      );
      expect(saved.id, isNotNull);
      expect(saved.isActive, isTrue);
      var list = await repo.listMyJobSeekPosts();
      expect(list, hasLength(1));

      // Deactivate (toggle)
      await repo.upsertJobSeekPost(saved.copyWith(isActive: false));
      list = await repo.listMyJobSeekPosts();
      expect(list.first.isActive, isFalse);

      // Delete
      await repo.deleteJobSeekPost(saved.id!);
      list = await repo.listMyJobSeekPosts();
      expect(list, isEmpty);
    });

    test('LocalWorkerRepository tecrübe ekle/listele/sil', () async {
      final repo = LocalWorkerRepository();
      final saved = await repo.addExperience(WorkerExperience(
        title: 'Taş Fırın Ustası',
        workplace: 'Konak Fırını',
        city: 'İstanbul',
        startDate: DateTime(2020, 1),
        endDate: DateTime(2024, 1),
      ));
      var list = await repo.listMyExperiences();
      expect(list, hasLength(1));
      expect(list.first.title, 'Taş Fırın Ustası');

      await repo.deleteExperience(saved.id!);
      list = await repo.listMyExperiences();
      expect(list, isEmpty);
    });
  });
}
