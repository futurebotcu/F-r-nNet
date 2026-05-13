import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/app_router.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_tokens.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/widgets/app_primary_button.dart';
import '../../../core/widgets/premium/premium_scaffold.dart';
import '../../auth/services/auth_required_guard.dart';
import '../models/group_category.dart';
import '../providers/social_group_providers.dart';

/// Yeni grup oluşturma formu — V1.
class GroupCreateScreen extends ConsumerStatefulWidget {
  const GroupCreateScreen({super.key});

  @override
  ConsumerState<GroupCreateScreen> createState() =>
      _GroupCreateScreenState();
}

const _limitOptions = <_LimitChoice>[
  _LimitChoice(label: '25 kişi', value: 25),
  _LimitChoice(label: '50 kişi', value: 50),
  _LimitChoice(label: '100 kişi', value: 100),
  _LimitChoice(label: '250 kişi', value: 250),
  _LimitChoice(label: AppStrings.groupCreateLimitUnlimited, value: null),
];

class _LimitChoice {
  const _LimitChoice({required this.label, required this.value});
  final String label;
  final int? value; // null = unlimited
}

class _GroupCreateScreenState extends ConsumerState<GroupCreateScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _description = TextEditingController();
  final _city = TextEditingController();
  final _tags = TextEditingController();

  GroupCategory _category = GroupCategory.bakers;
  bool _private = false;
  _LimitChoice _limit = _limitOptions[2]; // 100 kişi default

  @override
  void dispose() {
    _name.dispose();
    _description.dispose();
    _city.dispose();
    _tags.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final validator = ref.read(groupValidatorProvider);
    final nameErr = validator.validateName(_name.text);
    final descErr = validator.validateDescription(_description.text);
    final limitErr = validator.validateLimit(_limit.value);

    if (!_formKey.currentState!.validate() ||
        nameErr != null ||
        descErr != null ||
        limitErr != null) {
      // FormState validate name/desc'i errorText üzerinden gösterir.
      if (limitErr != null) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(limitErr)));
      }
      return;
    }

    final repo = ref.read(socialGroupRepositoryProvider);
    final tags = _tags.text
        .split(',')
        .map((t) => t.trim())
        .where((t) => t.isNotEmpty)
        .toList();

    await runGuardedMutation(
      context,
      ref,
      action: () async {
        final group = await repo.createGroup(
          name: _name.text.trim(),
          description: _description.text.trim(),
          category: _category,
          city: _city.text.trim(),
          isPrivate: _private,
          maxMembers: _limit.value,
          tags: tags,
        );
        if (!mounted) return;
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('${AppStrings.groupCreatedSnack}${group.name}')),
        );
        context.push('${AppRoutes.groups}/${group.id}');
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final validator = ref.read(groupValidatorProvider);
    return PremiumScaffold(
      appBar: AppBar(title: const Text(AppStrings.groupCreateTitle)),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.pageH,
              0,
              AppSpacing.pageH,
              AppSpacing.xxl,
            ),
            children: [
              const _Label(AppStrings.groupCreateFieldName),
              const SizedBox(height: 6),
              TextFormField(
                controller: _name,
                textCapitalization: TextCapitalization.words,
                validator: validator.validateName,
                decoration: const InputDecoration(
                  hintText: AppStrings.groupCreateFieldNameHint,
                ),
              ),
              const SizedBox(height: AppSpacing.l),
              const _Label(AppStrings.groupCreateFieldDescription),
              const SizedBox(height: 6),
              TextFormField(
                controller: _description,
                maxLines: 3,
                validator: validator.validateDescription,
                decoration: const InputDecoration(
                  hintText: AppStrings.groupCreateFieldDescriptionHint,
                ),
              ),
              const SizedBox(height: AppSpacing.l),
              const _Label(AppStrings.groupCreateFieldCategory),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final c in GroupCategory.values)
                    ChoiceChip(
                      label: Text(c.label),
                      selected: _category == c,
                      onSelected: (_) => setState(() => _category = c),
                    ),
                ],
              ),
              const SizedBox(height: AppSpacing.l),
              const _Label(AppStrings.groupCreateFieldCity),
              const SizedBox(height: 6),
              TextFormField(
                controller: _city,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  hintText: AppStrings.groupCreateFieldCityHint,
                ),
              ),
              const SizedBox(height: AppSpacing.l),
              const _Label(AppStrings.groupCreateFieldPrivacy),
              const SizedBox(height: 8),
              SegmentedButton<bool>(
                segments: const [
                  ButtonSegment(
                    value: false,
                    label: Text(AppStrings.groupCreatePrivacyPublic),
                    icon: Icon(Icons.public_rounded),
                  ),
                  ButtonSegment(
                    value: true,
                    label: Text(AppStrings.groupCreatePrivacyPrivate),
                    icon: Icon(Icons.lock_rounded),
                  ),
                ],
                selected: {_private},
                onSelectionChanged: (s) => setState(() => _private = s.first),
              ),
              const SizedBox(height: AppSpacing.l),
              const _Label(AppStrings.groupCreateFieldLimit),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final opt in _limitOptions)
                    ChoiceChip(
                      label: Text(opt.label),
                      selected: _limit == opt,
                      onSelected: (_) => setState(() => _limit = opt),
                    ),
                ],
              ),
              const SizedBox(height: AppSpacing.l),
              const _Label(AppStrings.groupCreateFieldTags),
              const SizedBox(height: 6),
              TextFormField(
                controller: _tags,
                decoration: const InputDecoration(
                  hintText: AppStrings.groupCreateFieldTagsHint,
                ),
              ),
              const SizedBox(height: AppSpacing.xl),
              AppPrimaryButton(
                label: AppStrings.groupCreateButton,
                icon: Icons.check_rounded,
                onPressed: _save,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Label extends StatelessWidget {
  const _Label(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Text(
        text,
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w800,
          color: AppColors.textPrimary,
          letterSpacing: -0.1,
        ),
      );
}
