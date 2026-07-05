import 'package:flutter/material.dart';

import '../../../core/constants/app_strings.dart';
import '../../../core/widgets/guide/guide_message.dart';

/// Şube personel ekleme ekranının guide tanımları — tek karar noktası.
///
/// [staffAddGuide] her yeni personel ekleme işleminde alt rehber olarak
/// görünür (kalıcı gizleme yok; kapatma o işlem oturumu içindir).
/// [inviteSentBanner] davet başarıyla gönderilince üst success şerididir.
class BranchGuides {
  const BranchGuides._();

  static const String screenKey = 'branch_staff_add';

  static const GuideMessage staffAddGuide = GuideMessage(
    id: 'branch_staff_add_guide',
    title: AppStrings.branchStaffGuideTitle,
    body: AppStrings.branchStaffGuideBody,
    placement: GuidePlacement.bottomGuide,
    variant: GuideVariant.tip,
    persistence: GuidePersistence.sessionPersistent,
    screenKey: screenKey,
    allowedRoles: {'commercial'},
    priority: 10,
    icon: Icons.store_mall_directory_outlined,
    steps: [
      GuideStep(
        title: AppStrings.branchStaffGuideStep1Title,
        body: AppStrings.branchStaffGuideStep1Body,
      ),
      GuideStep(
        title: AppStrings.branchStaffGuideStep2Title,
        body: AppStrings.branchStaffGuideStep2Body,
      ),
      GuideStep(
        title: AppStrings.branchStaffGuideStep3Title,
        body: AppStrings.branchStaffGuideStep3Body,
      ),
      GuideStep(
        title: AppStrings.branchStaffGuideStep4Title,
        body: AppStrings.branchStaffGuideStep4Body,
      ),
      GuideStep(
        title: AppStrings.branchStaffGuideStep5Title,
        body: AppStrings.branchStaffGuideStep5Body,
      ),
      GuideStep(
        title: AppStrings.branchStaffGuideStep6Title,
        body: AppStrings.branchStaffGuideStep6Body,
      ),
    ],
    footnote: AppStrings.branchStaffGuideFootnote,
  );

  static const GuideMessage inviteSentBanner = GuideMessage(
    id: 'branch_invite_sent',
    title: AppStrings.branchInviteSentBannerTitle,
    body: AppStrings.branchInviteSentBannerBody,
    placement: GuidePlacement.topBanner,
    variant: GuideVariant.success,
    persistence: GuidePersistence.transient,
    screenKey: screenKey,
    allowedRoles: {'commercial'},
    icon: Icons.check_circle_rounded,
  );
}
