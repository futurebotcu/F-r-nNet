import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_tokens.dart';
import '../../../core/widgets/guide/app_guide_surface.dart';
import '../../../core/widgets/premium/premium_scaffold.dart';
import '../guides/driver_add_guide.dart';
import '../models/dealer_driver.dart';
import '../providers/dealer_providers.dart';

/// Şoför Ekle (Sprint 2).
///
/// Patron, şoförün FırınNet kullanıcı/profile ID'sini + ad/telefon/not girer.
/// Güvenlik notu: bu sprintte basit profile-ID girişi kullanılır; geçerlilik
/// DB FK ile doğrulanır (geçersiz ID reddedilir). Public FN-ID araması veya
/// geniş kullanıcı araması EKLENMEDİ (kimlik sızıntısı riski) — nihai davet/
/// onay akışı Sprint 6'ya bırakıldı.
class AddDriverScreen extends ConsumerStatefulWidget {
  const AddDriverScreen({super.key});

  /// Bilgi popup metinleri (test referansı için public).
  static const String halfPermissionInfo =
      'Şoför teslimat, tahsilat, iade girer; atanmış bayileri ve geçmişi '
      'görür. Fiyat, bayi bilgisi, işlem silme/düzeltme gibi patron '
      'işlemlerini yapamaz.';
  static const String fullPermissionInfo =
      'Şoför, atanmış bayiler için Bayi Yönetimi\'ni patron gibi '
      'kullanabilir. Fiyat düzenleme, işlem silme/düzeltme ve müşteri hesap '
      'dökümü işlemlerini yapabilir. Şoförler menüsü ve başka şoför/atanmamış '
      'bayi verileri yine kapalıdır.';

  @override
  ConsumerState<AddDriverScreen> createState() => _AddDriverScreenState();
}

class _AddDriverScreenState extends ConsumerState<AddDriverScreen> {
  final _userId = TextEditingController();
  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _note = TextEditingController();
  bool _saving = false;
  String? _error;
  DriverPermission _permission = DriverPermission.half;

  @override
  void dispose() {
    _userId.dispose();
    _name.dispose();
    _phone.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving) return;
    final fnId = _userId.text.trim();
    final name = _name.text.trim();
    if (fnId.isEmpty) {
      setState(
        () => _error = 'Davet oluşturulamadı. FırınNet ID\'yi kontrol edin.',
      );
      return;
    }
    if (name.isEmpty) {
      setState(() => _error = 'Şoför adını gir.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await ref
          .read(dealerRepositoryProvider)
          .createDriverInvite(
            firinnetId: fnId,
            name: name,
            phone: _phone.text.trim(),
            note: _note.text.trim(),
            permissionLevel: _permission,
          );
      if (!mounted) return;
      // Kısa success şeridi root overlay'de gösterilir; pop sonrası şoför
      // listesinin üstünde görünmeye devam eder (kullanıcıyı bölmez,
      // kendiliğinden kapanır).
      AppGuideOverlay.showTopBanner(
        context,
        message: DriverGuides.driverAddedBanner,
      );
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = e is StateError
            ? e.message
            : 'Davet oluşturulamadı. FırınNet ID\'yi kontrol edin.';
      });
    }
  }

  void _showPermissionInfo() {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.pageH,
            0,
            AppSpacing.pageH,
            AppSpacing.l,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: const [
              Text(
                'Yarı Yetki',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
              ),
              SizedBox(height: 6),
              Text(
                AddDriverScreen.halfPermissionInfo,
                style: TextStyle(fontSize: 13, height: 1.4),
              ),
              SizedBox(height: AppSpacing.m),
              Text(
                'Tam Yetki',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
              ),
              SizedBox(height: 6),
              Text(
                AddDriverScreen.fullPermissionInfo,
                style: TextStyle(fontSize: 13, height: 1.4),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PremiumScaffold(
      appBar: AppBar(title: const Text('Şoför Daveti Gönder')),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            Expanded(child: _buildForm()),
            // İşlem rehberi — altta panel olarak durur; formu kilitlemez,
            // her yeni şoför ekleme girişinde yeniden görünür (state ekrana
            // aittir, kalıcı gizleme yok). Form hatası gösterilirken rehber
            // otomatik küçülür; hata mesajı önceliklidir. Klavye açılınca
            // da küçülür (AppGuideSurface içinde).
            AppGuideSurface(
              message: DriverGuides.driverAddGuide,
              forceCollapsed: _error != null,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildForm() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.pageH,
        AppSpacing.m,
        AppSpacing.pageH,
        AppSpacing.xxl,
      ),
      children: [
        _field(
          controller: _userId,
          label: 'FırınNet ID',
          hint: 'Örn. FN-2026-000123',
        ),
        const SizedBox(height: AppSpacing.s),
        const Text(
          'Şoförün Ayarlar ekranında görünen FırınNet ID\'sini gir. Davet '
          'gönderilir; şoför kendi hesabından onaylayınca bağlantı aktif olur.',
          style: TextStyle(
            fontSize: 11.5,
            color: AppColors.textMuted,
            height: 1.35,
          ),
        ),
        const SizedBox(height: AppSpacing.m),
        _field(controller: _name, label: 'Şoför Adı'),
        const SizedBox(height: AppSpacing.m),
        _field(
          controller: _phone,
          label: 'Telefon (opsiyonel)',
          keyboardType: TextInputType.phone,
        ),
        const SizedBox(height: AppSpacing.m),
        _field(controller: _note, label: 'Not (opsiyonel)', maxLines: 3),
        const SizedBox(height: AppSpacing.l),
        Row(
          children: [
            const Text(
              'Yetki Seviyesi',
              style: TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
              ),
            ),
            IconButton(
              visualDensity: VisualDensity.compact,
              icon: const Icon(Icons.info_outline, size: 19),
              tooltip: 'Yetki seviyeleri',
              onPressed: _showPermissionInfo,
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.xs),
        SegmentedButton<DriverPermission>(
          segments: const [
            ButtonSegment(
              value: DriverPermission.half,
              label: Text('Yarı Yetki'),
              icon: Icon(Icons.shield_outlined, size: 18),
            ),
            ButtonSegment(
              value: DriverPermission.full,
              label: Text('Tam Yetki'),
              icon: Icon(Icons.verified_user_outlined, size: 18),
            ),
          ],
          selected: {_permission},
          onSelectionChanged: (s) => setState(() => _permission = s.first),
        ),
        const SizedBox(height: AppSpacing.s),
        Text(
          _permission == DriverPermission.full
              ? AddDriverScreen.fullPermissionInfo
              : AddDriverScreen.halfPermissionInfo,
          style: const TextStyle(
            fontSize: 11.5,
            color: AppColors.textMuted,
            height: 1.35,
          ),
        ),
        if (_error != null) ...[
          const SizedBox(height: AppSpacing.m),
          Text(
            _error!,
            style: const TextStyle(
              color: AppColors.danger,
              fontSize: 13,
              height: 1.35,
            ),
          ),
        ],
        const SizedBox(height: AppSpacing.l),
        SizedBox(
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
                fontWeight: FontWeight.w800,
                fontSize: 15,
              ),
            ),
            child: Text(_saving ? 'Gönderiliyor…' : 'Davet Gönder'),
          ),
        ),
      ],
    );
  }

  Widget _field({
    required TextEditingController controller,
    required String label,
    String? hint,
    int maxLines = 1,
    TextInputType? keyboardType,
  }) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      keyboardType: keyboardType,
      style: const TextStyle(fontSize: 14.5, color: AppColors.textPrimary),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        filled: true,
        fillColor: AppColors.surfaceVariant,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.m),
          borderSide: const BorderSide(
            color: AppColors.borderHairline,
            width: 0.8,
          ),
        ),
      ),
    );
  }
}
