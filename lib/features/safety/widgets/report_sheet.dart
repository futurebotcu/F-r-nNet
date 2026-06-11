// FırınNet UGC Safety V1 — şikayet bottom sheet'i.
//
// Tüm UGC yüzeylerinden (feed post, yorum, grup mesajı, ilan, profil) ortak
// kullanılır. Guest → AuthRequiredSheet (auth gerekli kararı V1).
// Başarı/duplicate/hata PremiumTopBanner ile bildirilir; içerik silinmez.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_tokens.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/widgets/premium/premium_top_banner.dart';
import '../../auth/services/auth_required_guard.dart';
import '../models/report_models.dart';
import '../providers/safety_providers.dart';

/// Şikayet akışını başlatır: guard → sheet → submit → banner.
///
/// [reportedUserId] içerik sahibinin uid'si (kendi içeriğini şikayet UI'da
/// zaten sunulmaz; repo katmanı da [SelfTargetException] ile reddeder).
Future<void> showReportSheet(
  BuildContext context,
  WidgetRef ref, {
  required ReportTargetType targetType,
  required String targetId,
  String? reportedUserId,
}) async {
  if (!AuthRequiredGuard.canWriteWithRef(ref)) {
    await showAuthRequiredSheet(context, ref);
    return;
  }
  if (!context.mounted) return;
  await showModalBottomSheet<void>(
    context: context,
    backgroundColor: AppColors.surface,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
    ),
    builder: (ctx) => _ReportSheet(
      parentRef: ref,
      targetType: targetType,
      targetId: targetId,
      reportedUserId: reportedUserId,
    ),
  );
}

class _ReportSheet extends StatefulWidget {
  const _ReportSheet({
    required this.parentRef,
    required this.targetType,
    required this.targetId,
    this.reportedUserId,
  });

  final WidgetRef parentRef;
  final ReportTargetType targetType;
  final String targetId;
  final String? reportedUserId;

  @override
  State<_ReportSheet> createState() => _ReportSheetState();
}

class _ReportSheetState extends State<_ReportSheet> {
  ReportReason? _reason;
  final TextEditingController _details = TextEditingController();
  bool _submitting = false;

  @override
  void dispose() {
    _details.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final reason = _reason;
    if (reason == null || _submitting) return;
    setState(() => _submitting = true);
    final repo = widget.parentRef.read(safetyRepositoryProvider);
    try {
      final result = await repo.reportContent(
        targetType: widget.targetType,
        targetId: widget.targetId,
        reportedUserId: widget.reportedUserId,
        reason: reason,
        details: _details.text,
      );
      if (!mounted) return;
      Navigator.of(context).pop();
      PremiumTopBannerController.show(
        context,
        message: result == ReportResult.duplicate
            ? AppStrings.reportDuplicateBanner
            : AppStrings.reportSuccessBanner,
        tone: result == ReportResult.duplicate
            ? PremiumTopBannerTone.info
            : PremiumTopBannerTone.success,
      );
    } on GuestActionRequiredException {
      if (!mounted) return;
      Navigator.of(context).pop();
      await showAuthRequiredSheet(context, widget.parentRef);
    } catch (_) {
      if (!mounted) return;
      setState(() => _submitting = false);
      PremiumTopBannerController.show(
        context,
        message: AppStrings.reportErrorBanner,
        tone: PremiumTopBannerTone.danger,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          AppSpacing.l,
          AppSpacing.m,
          AppSpacing.l,
          AppSpacing.l + bottomInset,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.only(bottom: AppSpacing.m),
                decoration: BoxDecoration(
                  color: AppColors.borderHairline,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const Padding(
              padding: EdgeInsets.only(left: 4, bottom: AppSpacing.s),
              child: Text(
                AppStrings.reportSheetTitle,
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                  letterSpacing: -0.2,
                ),
              ),
            ),
            Flexible(
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (final reason in ReportReason.values)
                      RadioListTile<ReportReason>(
                        value: reason,
                        groupValue: _reason,
                        onChanged: _submitting
                            ? null
                            : (v) => setState(() => _reason = v),
                        dense: true,
                        contentPadding:
                            const EdgeInsets.symmetric(horizontal: 4),
                        activeColor: AppColors.copper,
                        title: Text(
                          reason.label,
                          style: const TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 13.5,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.s),
            TextField(
              controller: _details,
              enabled: !_submitting,
              maxLines: 2,
              maxLength: 500,
              decoration: const InputDecoration(
                hintText: AppStrings.reportDetailsHint,
                counterText: '',
                isDense: true,
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: AppSpacing.m),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: FilledButton(
                onPressed:
                    (_reason != null && !_submitting) ? _submit : null,
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.copper,
                  foregroundColor: AppColors.surface,
                  disabledBackgroundColor: AppColors.surfaceLine,
                  disabledForegroundColor: AppColors.textMuted,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadius.m),
                  ),
                ),
                child: _submitting
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 1.8),
                      )
                    : const Text(
                        AppStrings.reportSubmit,
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.6,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
