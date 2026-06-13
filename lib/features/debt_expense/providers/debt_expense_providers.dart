import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;

import '../../../core/config/app_config.dart';
import '../../auth/providers/auth_providers.dart';
import '../../auth/providers/can_write_check_provider.dart';
import '../models/debt_expense_entry.dart';
import '../repositories/debt_expense_repository.dart';
import '../repositories/guarded_debt_expense_repository.dart';
import '../repositories/local_debt_expense_repository.dart';
import '../repositories/supabase_debt_expense_repository.dart';

/// Borç & Gider mini-app aktif tab indeksi (0 = Genel Bakış).
final debtExpenseShellTabIndexProvider = StateProvider<int>((_) => 0);

/// Borç & Gider repository — dealer pattern: yalnız userId izlenir
/// (token refresh repo'yu resetlemesin); guest/offline'da Local.
final debtExpenseRepositoryProvider = Provider<DebtExpenseRepository>((ref) {
  final userId = ref.watch(currentAuthUserProvider.select((u) => u?.id));
  final DebtExpenseRepository inner;
  if (AppConfig.supabaseEnabled && userId != null) {
    inner = SupabaseDebtExpenseRepository(sb.Supabase.instance.client);
  } else {
    inner = LocalDebtExpenseRepository();
  }
  final canWrite = ref.watch(canWriteCheckProvider);
  final repo =
      GuardedDebtExpenseRepository(inner: inner, canWriteCheck: canWrite);
  ref.onDispose(repo.dispose);
  return repo;
});

/// İçerik (kayıt/ödeme) değişim tick'i.
final debtExpenseChangesProvider = StreamProvider<void>((ref) {
  final repo = ref.watch(debtExpenseRepositoryProvider);
  return repo.watch();
});

/// Tür bazlı (veya tüm) kayıt listesi. null → hepsi.
final debtExpenseEntriesProvider = FutureProvider.autoDispose
    .family<List<DebtExpenseEntry>, DebtExpenseKind?>((ref, kind) async {
  ref.watch(debtExpenseChangesProvider);
  final repo = ref.watch(debtExpenseRepositoryProvider);
  return repo.listEntries(kind: kind);
});

/// Genel Bakış / Raporlar özeti.
class DebtExpenseSummary {
  const DebtExpenseSummary({
    required this.openDebtTotal,
    required this.thisMonthExpense,
    required this.staffPayableTotal,
    required this.upcomingThisWeek,
    required this.overdueCount,
    required this.overdueTotal,
    required this.closedDebtCount,
  });

  final double openDebtTotal; // açık borçların kalan toplamı
  final double thisMonthExpense; // bu ay gider toplamı
  final double staffPayableTotal; // ödenecek personel toplamı (kalan)
  final int upcomingThisWeek; // 7 gün içinde vadesi gelen (kapanmamış)
  final int overdueCount;
  final double overdueTotal;
  final int closedDebtCount;
}

/// Özet — tüm kayıtlardan türetilir (today = DateTime.now()).
final debtExpenseSummaryProvider =
    FutureProvider.autoDispose<DebtExpenseSummary>((ref) async {
  ref.watch(debtExpenseChangesProvider);
  final repo = ref.watch(debtExpenseRepositoryProvider);
  final all = await repo.listEntries();
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final weekEnd = today.add(const Duration(days: 7));
  final monthStart = DateTime(now.year, now.month, 1);

  double openDebt = 0;
  double monthExpense = 0;
  double staffPayable = 0;
  int upcoming = 0;
  int overdueCount = 0;
  double overdueTotal = 0;
  int closedDebt = 0;

  for (final e in all) {
    final st = e.statusOn(today);
    if (e.kind == DebtExpenseKind.debt) {
      if (st == DebtExpenseStatus.paid) {
        closedDebt++;
      } else {
        openDebt += e.remaining;
      }
    } else if (e.kind == DebtExpenseKind.expense) {
      if (!e.createdAt.isBefore(monthStart)) monthExpense += e.totalAmount;
    } else if (e.kind == DebtExpenseKind.staffPayment) {
      if (st != DebtExpenseStatus.paid) staffPayable += e.remaining;
    }

    if (st != DebtExpenseStatus.paid && e.dueDate != null) {
      final d = DateTime(e.dueDate!.year, e.dueDate!.month, e.dueDate!.day);
      if (st == DebtExpenseStatus.overdue) {
        overdueCount++;
        overdueTotal += e.remaining;
      } else if (!d.isBefore(today) && d.isBefore(weekEnd)) {
        upcoming++;
      }
    }
  }

  return DebtExpenseSummary(
    openDebtTotal: openDebt,
    thisMonthExpense: monthExpense,
    staffPayableTotal: staffPayable,
    upcomingThisWeek: upcoming,
    overdueCount: overdueCount,
    overdueTotal: overdueTotal,
    closedDebtCount: closedDebt,
  );
});
