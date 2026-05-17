import 'package:flutter/material.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_tokens.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/widgets/premium/premium_card.dart';
import '../../../core/widgets/premium/premium_scaffold.dart';

/// V1.4 — Verilerim hakkında bilgi statik ekranı.
///
/// Yasal döküman değildir; kullanıcıya hesabında hangi verilerin
/// tutulduğunu ve hesap silindiğinde ne olacağını özet anlatır.
/// Yasal kapsam için Gizlilik Politikası + Kullanım Şartları ekranları
/// kullanılır.
class DataInfoScreen extends StatelessWidget {
  const DataInfoScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return PremiumScaffold(
      appBar: AppBar(title: const Text(AppStrings.dataInfoTitle)),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.pageH),
          children: [
            PremiumCard(
              padding: const EdgeInsets.all(AppSpacing.l),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Icon(
                    Icons.info_outline_rounded,
                    color: AppColors.softGold,
                    size: 22,
                  ),
                  SizedBox(height: AppSpacing.s),
                  Text(
                    AppStrings.dataInfoBody,
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      height: 1.55,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
