import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_tokens.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/widgets/guide/app_guide_surface.dart';
import '../../../core/widgets/premium/premium_scaffold.dart';
import '../guides/branch_staff_guide.dart';
import '../models/branch_models.dart';
import '../providers/branch_providers.dart';

/// Şube personeli davet ekranı — FırınNet ID + şube + rol + süreç izinleri.
///
/// Şoför davet akışının şube karşılığı: FN-ID server-side çözülür (RPC),
/// hedef bireysel değilse/bulunamazsa nötr hata döner. Altta "Çalışan nasıl
/// eklenir?" rehber paneli her yeni işlemde görünür; form hatasında rehber
/// otomatik küçülür.
class AddBranchStaffScreen extends ConsumerStatefulWidget {
  const AddBranchStaffScreen({super.key, this.initialBranchId});

  final String? initialBranchId;

  @override
  ConsumerState<AddBranchStaffScreen> createState() =>
      _AddBranchStaffScreenState();
}

class _AddBranchStaffScreenState extends ConsumerState<AddBranchStaffScreen> {
  final _fnId = TextEditingController();
  String? _branchId;
  BranchRole _role = BranchRole.counter;
  final Set<BranchProcessType> _permissions = {};
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _branchId = widget.initialBranchId;
  }

  @override
  void dispose() {
    _fnId.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    if (_saving) return;
    if (_fnId.text.trim().isEmpty) {
      setState(() => _error = AppStrings.branchInviteFnIdRequired);
      return;
    }
    if (_branchId == null) {
      setState(() => _error = AppStrings.branchInviteBranchRequired);
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await ref
          .read(branchRepositoryProvider)
          .createStaffInvite(
            branchId: _branchId!,
            firinnetId: _fnId.text,
            role: _role,
            permissions: _permissions.toList(growable: false),
          );
      if (!mounted) return;
      AppGuideOverlay.showTopBanner(
        context,
        message: BranchGuides.inviteSentBanner,
      );
      Navigator.of(context).pop();
    } on StateError catch (e) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = e.message;
      });
    } catch (_) {
      // Beklenmeyen hata (ağ vb.) — FN-ID mesajı yanıltıcı olur; nötr genel
      // mesaj göster (enumeration sızdırmayan dil korunur).
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = AppStrings.branchInviteGenericError;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return PremiumScaffold(
      appBar: AppBar(title: const Text(AppStrings.branchInviteTitle)),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            Expanded(child: _buildForm()),
            // "Çalışan nasıl eklenir?" — her yeni davet işleminde görünür;
            // form hatası varken küçülür (hata mesajı önceliklidir).
            AppGuideSurface(
              message: BranchGuides.staffAddGuide,
              forceCollapsed: _error != null,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildForm() {
    final branches = ref.watch(myBranchesProvider).valueOrNull ?? const [];
    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.pageH,
        AppSpacing.m,
        AppSpacing.pageH,
        AppSpacing.xxl,
      ),
      children: [
        TextField(
          controller: _fnId,
          style: const TextStyle(fontSize: 14.5, color: AppColors.textPrimary),
          decoration: InputDecoration(
            labelText: AppStrings.branchInviteFnIdLabel,
            hintText: AppStrings.branchInviteFnIdHint,
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
        ),
        const SizedBox(height: AppSpacing.m),
        DropdownButtonFormField<String>(
          key: const ValueKey('branch_invite_branch_picker'),
          initialValue: _branchId,
          items: [
            for (final b in branches)
              DropdownMenuItem(value: b.id, child: Text(b.name)),
          ],
          onChanged: (v) => setState(() => _branchId = v),
          decoration: const InputDecoration(
            labelText: AppStrings.branchInviteBranchField,
          ),
        ),
        const SizedBox(height: AppSpacing.l),
        const Text(
          AppStrings.branchInviteRoleField,
          style: TextStyle(
            fontSize: 13.5,
            fontWeight: FontWeight.w800,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (final role in BranchRole.values)
              ChoiceChip(
                key: ValueKey('branch_role_${role.persistKey}'),
                label: Text(role.label),
                selected: _role == role,
                onSelected: (_) => setState(() => _role = role),
                labelStyle: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
                selectedColor: AppColors.brandLemonPale,
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.l),
        const Text(
          AppStrings.branchInvitePermissionsField,
          style: TextStyle(
            fontSize: 13.5,
            fontWeight: FontWeight.w800,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        if (_role.hasAllProcessPermissions)
          const Text(
            'Şube sorumlusu tüm süreç tiplerine yetkilidir.',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.textMuted,
            ),
          )
        else
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final type in BranchProcessType.values)
                FilterChip(
                  key: ValueKey('branch_perm_${type.persistKey}'),
                  label: Text(type.label),
                  selected: _permissions.contains(type),
                  onSelected: (on) => setState(() {
                    if (on) {
                      _permissions.add(type);
                    } else {
                      _permissions.remove(type);
                    }
                  }),
                  labelStyle: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                  selectedColor: AppColors.brandLemonPale,
                  checkmarkColor: AppColors.brandInk,
                ),
            ],
          ),
        // Bilgi notu: izin seçilmezse personel salt-görüntüleyici kalır.
        // Daveti engellemez; patronun bilinçli seçim yapmasını sağlar.
        if (!_role.hasAllProcessPermissions && _permissions.isEmpty) ...[
          const SizedBox(height: AppSpacing.s),
          Row(
            key: const ValueKey('branch_invite_permission_note'),
            crossAxisAlignment: CrossAxisAlignment.start,
            children: const [
              Icon(
                Icons.info_outline_rounded,
                size: 15,
                color: AppColors.textMuted,
              ),
              SizedBox(width: 6),
              Expanded(
                child: Text(
                  AppStrings.branchInviteNoPermissionNote,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textMuted,
                    height: 1.35,
                  ),
                ),
              ),
            ],
          ),
        ],
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
            key: const ValueKey('branch_invite_send'),
            onPressed: _saving ? null : _send,
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
            child: Text(
              _saving
                  ? AppStrings.branchInviteSending
                  : AppStrings.branchInviteSend,
            ),
          ),
        ),
      ],
    );
  }
}
