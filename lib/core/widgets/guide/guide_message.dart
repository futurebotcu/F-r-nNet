import 'package:flutter/widgets.dart';

/// Rehber/bilgilendirme yüzeyinin ekrandaki yerleşimi.
///
/// - [topBanner]: üstte ince, kısa bilgilendirme şeridi (kullanıcıyı bölmez).
/// - [bottomGuide]: altta geniş işlem rehberi paneli (adım anlatımı; formu
///   kilitlemez, modal değildir).
/// - [inlineGuide]: form içinde küçük açıklama (ileride kullanım için).
/// - [floatingBottom]: altta yüzen, içeriği kapatmadan duran rehber.
enum GuidePlacement { topBanner, bottomGuide, inlineGuide, floatingBottom }

/// Mesajın tonu — renk/ikon ailesini belirler.
enum GuideVariant { info, tip, warning, success }

/// Mesajın kalıcılık davranışı (gösterim kararı çağıran yüzeye aittir;
/// model yalnız niyeti taşır).
///
/// - [transient]: kısa süreli, kendiliğinden kaybolabilir.
/// - [sessionPersistent]: kapatılana dek o oturumda kalır; kapatma yalnız
///   o işlem oturumu içindir, kalıcı gizleme DEĞİLDİR (örn. şoför ekleme
///   rehberi her yeni işlemde yeniden görünür).
/// - [untilCompleted]: ilgili işlem tamamlanana dek görünür.
/// - [dismissible]: kullanıcı kapatabilir; sonraki girişte yine görünebilir.
enum GuidePersistence {
  transient,
  sessionPersistent,
  untilCompleted,
  dismissible,
}

/// İşlem rehberindeki tek bir adım (başlık + kısa açıklama).
@immutable
class GuideStep {
  const GuideStep({required this.title, required this.body});

  final String title;
  final String body;
}

/// Uygulama içi yönlendirme/bilgilendirme mesajının merkezi tanımı.
///
/// Saf veri — UI içermez; [AppGuideSurface] bu modeli çizer. Rol ve ekran
/// eşlemesi burada metadata olarak taşınır; güvenlik kararı DEĞİLDİR
/// (ekranlar zaten route guard'larıyla korunur).
@immutable
class GuideMessage {
  const GuideMessage({
    required this.id,
    required this.title,
    required this.body,
    this.placement = GuidePlacement.topBanner,
    this.variant = GuideVariant.info,
    this.persistence = GuidePersistence.transient,
    this.screenKey,
    this.allowedRoles,
    this.priority = 0,
    this.icon,
    this.steps = const <GuideStep>[],
    this.ctaLabel,
    this.footnote,
    this.dismissible = true,
    this.showCondition,
  });

  /// Kararlı kimlik (test / telemetri / tekrar-gösterim kararları için).
  final String id;

  final String title;
  final String body;
  final GuidePlacement placement;
  final GuideVariant variant;
  final GuidePersistence persistence;

  /// Mesajın ait olduğu ekran anahtarı (örn. 'driver_add'). `null` = genel.
  final String? screenKey;

  /// Görünür olduğu rol anahtarları (AccountType.name). `null` = tüm roller.
  final Set<String>? allowedRoles;

  /// Aynı anda birden fazla aday varsa yüksek öncelik kazanır (üst üste
  /// binme yerine tek mesaj gösterilir).
  final int priority;

  final IconData? icon;

  /// İşlem rehberi adımları (yalnız geniş yerleşimlerde çizilir).
  final List<GuideStep> steps;

  /// Opsiyonel eylem etiketi.
  final String? ctaLabel;

  /// Adımların altında görünen küçük yardım notu (örn. "ID'yi bulamıyorsa
  /// ..."). Yalnız geniş yerleşimlerde çizilir.
  final String? footnote;

  /// Kullanıcı bu mesajı kapatabilir mi.
  final bool dismissible;

  /// Ek gösterim koşulu (örn. bir sayaç/duruma bağlı). `null` = her zaman.
  final bool Function()? showCondition;

  /// [roleKey] (AccountType.name) bu mesajı görebilir mi.
  bool isVisibleToRole(String? roleKey) =>
      allowedRoles == null ||
      (roleKey != null && allowedRoles!.contains(roleKey));

  /// Mesaj [key] ekranına mı ait (screenKey null ise her ekranda geçerli).
  bool matchesScreen(String key) => screenKey == null || screenKey == key;

  bool get shouldShow => showCondition?.call() ?? true;
}
