import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_tokens.dart';
import '../../../core/widgets/premium/premium_scaffold.dart';
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
    final userId = _userId.text.trim();
    final name = _name.text.trim();
    if (userId.isEmpty) {
      setState(() => _error = 'Şoförün FırınNet kullanıcı ID\'sini gir.');
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
      await ref.read(dealerRepositoryProvider).addDriver(
            driverUserId: userId,
            name: name,
            phone: _phone.text.trim(),
            note: _note.text.trim(),
          );
      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Şoför eklendi.')),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = e is StateError ? e.message : 'Şoför eklenemedi. Tekrar deneyin.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return PremiumScaffold(
      appBar: AppBar(title: const Text('Şoför Ekle')),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.pageH,
            AppSpacing.m,
            AppSpacing.pageH,
            AppSpacing.xxl,
          ),
          children: [
            _field(
              controller: _userId,
              label: 'FırınNet Kullanıcı ID',
              hint: 'Şoförün profil/kullanıcı ID\'si',
            ),
            const SizedBox(height: AppSpacing.s),
            const Text(
              'Şoför, kendi FırınNet hesabı olan bir kişidir. ID geçerli değilse '
              'ekleme reddedilir.',
              style: TextStyle(
                  fontSize: 11.5, color: AppColors.textMuted, height: 1.35),
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
            _field(
              controller: _note,
              label: 'Not (opsiyonel)',
              maxLines: 3,
            ),
            if (_error != null) ...[
              const SizedBox(height: AppSpacing.m),
              Text(_error!,
                  style: const TextStyle(
                      color: AppColors.danger, fontSize: 13, height: 1.35)),
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
                      fontWeight: FontWeight.w800, fontSize: 15),
                ),
                child: Text(_saving ? 'Kaydediliyor…' : 'Kaydet'),
              ),
            ),
          ],
        ),
      ),
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
          borderSide: const BorderSide(color: AppColors.borderHairline, width: 0.8),
        ),
      ),
    );
  }
}
