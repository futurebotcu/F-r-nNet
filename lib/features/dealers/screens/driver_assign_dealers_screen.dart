import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_tokens.dart';
import '../../../core/widgets/premium/premium_scaffold.dart';
import '../providers/dealer_providers.dart';

/// Şoföre bayi atama (Sprint 2): patronun KENDİ bayileri listelenir, çoklu seçim.
/// Seçim `setDriverAssignments` ile tam eşitlenir. Başka patronun bayisi
/// listelenmez (dealersListProvider owner-only RLS) + DB trigger ayrıca korur.
class DriverAssignDealersScreen extends ConsumerStatefulWidget {
  const DriverAssignDealersScreen({super.key, required this.driverId});
  final String driverId;

  @override
  ConsumerState<DriverAssignDealersScreen> createState() =>
      _DriverAssignDealersScreenState();
}

class _DriverAssignDealersScreenState
    extends ConsumerState<DriverAssignDealersScreen> {
  Set<String>? _selected; // null = henüz initial yüklenmedi
  bool _saving = false;

  Future<void> _save() async {
    if (_saving || _selected == null) return;
    setState(() => _saving = true);
    try {
      await ref.read(dealerRepositoryProvider).setDriverAssignments(
            driverId: widget.driverId,
            dealerIds: _selected!.toList(),
          );
      ref.invalidate(assignedDealerIdsProvider(widget.driverId));
      ref.invalidate(driverByIdProvider(widget.driverId));
      ref.invalidate(driversListProvider);
      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Atamalar kaydedildi.')),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Kaydedilemedi. Tekrar deneyin.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final dealersAsync = ref.watch(dealersListProvider);
    final assignedAsync = ref.watch(assignedDealerIdsProvider(widget.driverId));

    // İlk yüklemede mevcut atamayı seçime kopyala (bir kez).
    if (_selected == null && assignedAsync.hasValue) {
      _selected = assignedAsync.value!.toSet();
    }

    return PremiumScaffold(
      appBar: AppBar(title: const Text('Bayi Ata')),
      body: SafeArea(
        top: false,
        child: dealersAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, __) => const Center(
            child: Text('Bayiler yüklenemedi.',
                style: TextStyle(color: AppColors.textSecondary)),
          ),
          data: (dealers) {
            final selected = _selected ?? <String>{};
            if (dealers.isEmpty) {
              return const Center(
                child: Padding(
                  padding: EdgeInsets.all(AppSpacing.l),
                  child: Text(
                    'Önce bayi eklemelisin. Şoföre atamak için bayilerin olmalı.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        color: AppColors.textSecondary, height: 1.45),
                  ),
                ),
              );
            }
            return Column(
              children: [
                Expanded(
                  child: ListView.separated(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.pageH,
                      AppSpacing.m,
                      AppSpacing.pageH,
                      AppSpacing.m,
                    ),
                    itemCount: dealers.length,
                    separatorBuilder: (_, __) =>
                        const SizedBox(height: AppSpacing.xs),
                    itemBuilder: (_, i) {
                      final d = dealers[i];
                      final on = selected.contains(d.id);
                      return CheckboxListTile(
                        value: on,
                        onChanged: (v) {
                          setState(() {
                            final s = _selected ??= <String>{};
                            if (v == true) {
                              s.add(d.id);
                            } else {
                              s.remove(d.id);
                            }
                          });
                        },
                        title: Text(d.name,
                            style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 14.5,
                                color: AppColors.textPrimary)),
                        subtitle: (d.city.isNotEmpty || d.area.isNotEmpty)
                            ? Text(
                                [d.city, d.area]
                                    .where((e) => e.isNotEmpty)
                                    .join(' · '),
                                style: const TextStyle(
                                    fontSize: 12, color: AppColors.textMuted))
                            : null,
                        activeColor: AppColors.brandLemonPressed,
                        controlAffinity: ListTileControlAffinity.leading,
                      );
                    },
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.pageH,
                    AppSpacing.s,
                    AppSpacing.pageH,
                    AppSpacing.l,
                  ),
                  child: SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: _saving ? null : _save,
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.brandLemon,
                        foregroundColor: AppColors.brandInk,
                        minimumSize: const Size(0, 50),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppRadius.m),
                        ),
                        textStyle: const TextStyle(
                            fontWeight: FontWeight.w800, fontSize: 15),
                      ),
                      child: Text(_saving
                          ? 'Kaydediliyor…'
                          : 'Kaydet (${selected.length} bayi)'),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
