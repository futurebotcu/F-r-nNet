import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_tokens.dart';
import '../../../core/widgets/premium/premium_scaffold.dart';
import '../providers/dealer_providers.dart';

/// Bireysel şoför "henüz atanmamış" görünümü (fix/driver-normal-dealer-shell).
///
/// Atanmış bayisi olan şoför, normal [DealerShellScreen]'i (driverScoped:
/// Şoförler tabı yok + scoped data) görür — karar DealerShellScreen'de. Bu
/// ekran AYRI PANEL DEĞİL: yalnız davet bekleyen / hiç atanmamış şoför için
/// davet kartı + boş durumu gösterir.
class DriverHomeScreen extends ConsumerWidget {
  const DriverHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final invites = ref.watch(myDriverInvitesProvider).valueOrNull ?? const [];

    return PremiumScaffold(
      appBar: AppBar(title: const Text('Bayi Yönetimi')),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            if (invites.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(
                    AppSpacing.pageH, AppSpacing.s, AppSpacing.pageH, 0),
                child: const _MyInvites(),
              ),
            const Expanded(child: _DriverEmpty()),
          ],
        ),
      ),
    );
  }
}

/// Şoföre gelen bekleyen davetler — Kabul/Reddet. Boşsa görünmez.
class _MyInvites extends ConsumerWidget {
  const _MyInvites();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final invites = ref.watch(myDriverInvitesProvider).valueOrNull ?? const [];
    if (invites.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final inv in invites)
          Container(
            margin: const EdgeInsets.only(bottom: AppSpacing.s),
            padding: const EdgeInsets.all(AppSpacing.m),
            decoration: BoxDecoration(
              color: AppColors.brandLemonPale,
              borderRadius: BorderRadius.circular(AppRadius.m),
              border: Border.all(color: AppColors.brandLemonSoft, width: 0.8),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  inv.ownerName.isNotEmpty
                      ? '${inv.ownerName} seni şoför olarak eklemek istiyor'
                      : 'Bir işletme seni şoför olarak eklemek istiyor',
                  style: const TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                      color: AppColors.brandInk,
                      height: 1.35),
                ),
                const SizedBox(height: AppSpacing.s),
                Row(children: [
                  Expanded(
                    child: FilledButton(
                      onPressed: () => _respond(ref, inv.id, true),
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.brandLemon,
                        foregroundColor: AppColors.brandInk,
                        minimumSize: const Size(0, 40),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppRadius.m),
                        ),
                        textStyle: const TextStyle(
                            fontWeight: FontWeight.w800, fontSize: 13),
                      ),
                      child: const Text('Kabul Et'),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.s),
                  OutlinedButton(
                    onPressed: () => _respond(ref, inv.id, false),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.textSecondary,
                      side: const BorderSide(color: AppColors.borderHairline),
                      minimumSize: const Size(0, 40),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppRadius.m),
                      ),
                    ),
                    child: const Text('Reddet'),
                  ),
                ]),
              ],
            ),
          ),
      ],
    );
  }

  Future<void> _respond(WidgetRef ref, String inviteId, bool accept) async {
    await ref
        .read(dealerRepositoryProvider)
        .respondDriverInvite(inviteId, accept: accept);
    ref.invalidate(myDriverInvitesProvider);
    ref.invalidate(isAssignedDriverProvider);
    ref.invalidate(dealersAssignedToMeProvider);
  }
}

class _DriverEmpty extends StatelessWidget {
  const _DriverEmpty();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: AppColors.softGold.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(AppRadius.m),
              ),
              child: const Icon(Icons.local_shipping_outlined,
                  color: AppColors.softGold, size: 26),
            ),
            const SizedBox(height: AppSpacing.m),
            const Text('Henüz sana atanmış bayi yok',
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary)),
            const SizedBox(height: 4),
            const Text(
              'Fırın/işletme sana davet gönderip bayi atadığında burada görünecek.',
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 13, color: AppColors.textSecondary, height: 1.45),
            ),
          ],
        ),
      ),
    );
  }
}
