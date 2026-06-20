// Bayi Defteri Kullanılabilirlik Sprinti — işlem silme (C) birim testi.
// Patron (Local) işlem silebilir, bakiye yeniden hesaplanır; şoför scoped
// repo'da silme DriverPermissionException fırlatır.

import 'package:firin_defter/features/dealers/models/dealer_transaction.dart';
import 'package:firin_defter/features/dealers/repositories/driver_permission.dart';
import 'package:firin_defter/features/dealers/repositories/driver_scoped_dealer_repository.dart';
import 'package:firin_defter/features/dealers/repositories/local_dealer_repository.dart';
import 'package:firin_defter/features/dealers/services/dealer_balance_service.dart';
import 'package:flutter_test/flutter_test.dart';

DealerTransaction _payment(String id) => DealerTransaction(
      id: id,
      dealerId: 'd_hamdi',
      type: DealerTransactionType.payment,
      amount: 100,
      createdAt: DateTime.now(),
    );

void main() {
  const svc = DealerBalanceService();

  test('Patron işlem siler → kayıt gider, bakiye yeniden hesaplanır', () async {
    final repo = LocalDealerRepository(seed: true);
    final tx = _payment('t_del');
    await repo.addTransaction(tx);

    final mid = await repo.listTransactions('d_hamdi');
    final balMid =
        svc.summarize(dealerId: 'd_hamdi', transactions: mid).currentBalance;
    expect(mid.any((t) => t.id == 't_del'), isTrue);

    await repo.deleteTransaction(tx);

    final after = await repo.listTransactions('d_hamdi');
    expect(after.any((t) => t.id == 't_del'), isFalse);
    final balAfter =
        svc.summarize(dealerId: 'd_hamdi', transactions: after).currentBalance;
    // payment bakiyeyi 100 azaltmıştı; silinince geri eklenir.
    expect(balAfter, balMid + 100);
  });

  test('Şoför scoped repo: deleteTransaction → DriverPermissionException',
      () async {
    final scoped =
        DriverScopedDealerRepository(inner: LocalDealerRepository(seed: true));
    expect(
      () => scoped.deleteTransaction(_payment('x')),
      throwsA(isA<DriverPermissionException>()),
    );
  });
}
