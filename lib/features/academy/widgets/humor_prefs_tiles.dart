import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_colors.dart';
import '../../../core/constants/app_strings.dart';
import '../data/academy_repository.dart';
import '../providers/academy_providers.dart';

/// Ayarlar → FırınNet Mizah etkileşim tercihleri.
///
/// Kullanıcı tercihi UYGULAMADA çalışan aç/kapat kontrolüdür; sunucu
/// guard'ları gönderim ANINDA yeniden kontrol eder (izin geri çekildiğinde
/// bekleyen etkileşim de durur). Kendiliğinden DM varsayılanı KAPALIDIR.
class HumorPrefsTiles extends ConsumerWidget {
  const HumorPrefsTiles({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final prefsAsync = ref.watch(humorPrefsProvider);
    final prefs = prefsAsync.valueOrNull ?? const HumorPrefs();
    final busy = prefsAsync.isLoading;

    Future<void> save(HumorPrefs next) async {
      try {
        await ref.read(academyRepositoryProvider).setHumorPrefs(next);
      } catch (_) {
        // Yazım hatası: sessiz — tekrar denenebilir; server fail-closed.
      }
      ref.invalidate(humorPrefsProvider);
    }

    return Column(
      children: [
        SwitchListTile(
          key: const ValueKey('humor_pref_comments'),
          value: prefs.allowComments,
          onChanged: busy
              ? null
              : (v) => save(HumorPrefs(
                    allowComments: v,
                    allowDm: prefs.allowDm,
                  )),
          title: const Text(
            AppStrings.humorPrefCommentsTitle,
            style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700),
          ),
          subtitle: const Text(
            AppStrings.humorPrefCommentsSubtitle,
            style: TextStyle(fontSize: 12, color: AppColors.textMuted),
          ),
          activeThumbColor: AppColors.brandInk,
          activeTrackColor: AppColors.brandLemon,
        ),
        SwitchListTile(
          key: const ValueKey('humor_pref_dm'),
          value: prefs.allowDm,
          onChanged: busy
              ? null
              : (v) => save(HumorPrefs(
                    allowComments: prefs.allowComments,
                    allowDm: v,
                  )),
          title: const Text(
            AppStrings.humorPrefDmTitle,
            style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700),
          ),
          subtitle: const Text(
            AppStrings.humorPrefDmSubtitle,
            style: TextStyle(fontSize: 12, color: AppColors.textMuted),
          ),
          activeThumbColor: AppColors.brandInk,
          activeTrackColor: AppColors.brandLemon,
        ),
      ],
    );
  }
}
