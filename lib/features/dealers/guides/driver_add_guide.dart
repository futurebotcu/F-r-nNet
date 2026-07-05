import 'package:flutter/material.dart';

import '../../../core/constants/app_strings.dart';
import '../../../core/widgets/guide/guide_message.dart';

/// Şoför ekleme ekranının guide tanımları — tek karar noktası.
///
/// [driverAddGuide] her yeni şoför ekleme işleminde alt rehber olarak
/// görünür (oncePerUser DEĞİL; kapatma yalnız o işlem oturumu içindir).
/// [driverAddedBanner] kayıt başarılı olunca üstte kısa success şerididir.
class DriverGuides {
  const DriverGuides._();

  /// Alt rehberin ait olduğu ekran anahtarı.
  static const String screenKey = 'driver_add';

  static const GuideMessage driverAddGuide = GuideMessage(
    id: 'driver_add_guide',
    title: AppStrings.driverAddGuideTitle,
    body: AppStrings.driverAddGuideBody,
    placement: GuidePlacement.bottomGuide,
    variant: GuideVariant.tip,
    // Her işlemde yeniden görünür; kapatma o işlem oturumuyla sınırlıdır.
    persistence: GuidePersistence.sessionPersistent,
    screenKey: screenKey,
    allowedRoles: {'commercial'},
    priority: 10,
    icon: Icons.local_shipping_outlined,
    steps: [
      GuideStep(
        title: AppStrings.driverAddGuideStep1Title,
        body: AppStrings.driverAddGuideStep1Body,
      ),
      GuideStep(
        title: AppStrings.driverAddGuideStep2Title,
        body: AppStrings.driverAddGuideStep2Body,
      ),
      GuideStep(
        title: AppStrings.driverAddGuideStep3Title,
        body: AppStrings.driverAddGuideStep3Body,
      ),
      GuideStep(
        title: AppStrings.driverAddGuideStep4Title,
        body: AppStrings.driverAddGuideStep4Body,
      ),
    ],
    footnote: AppStrings.driverAddGuideFootnote,
  );

  static const GuideMessage driverAddedBanner = GuideMessage(
    id: 'driver_added_success',
    title: AppStrings.driverAddedBannerTitle,
    body: AppStrings.driverAddedBannerBody,
    placement: GuidePlacement.topBanner,
    variant: GuideVariant.success,
    persistence: GuidePersistence.transient,
    screenKey: screenKey,
    allowedRoles: {'commercial'},
    icon: Icons.check_circle_rounded,
  );
}
