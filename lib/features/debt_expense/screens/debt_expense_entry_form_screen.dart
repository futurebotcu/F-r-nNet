// Borç & Gider — kayıt ekleme formu (kind'e göre uyarlanır).
// Çift-submit guard + kategori preset + "Diğer/manuel" (ProductChoiceChips).

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_tokens.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/utils/number_formatter.dart';
import '../../../core/widgets/app_number_field.dart';
import '../../../core/widgets/app_primary_button.dart';
import '../../../core/widgets/premium/premium_scaffold.dart';
import '../../../core/widgets/product_choice_chips.dart';
import '../../auth/services/auth_required_guard.dart';
import '../data/debt_expense_categories.dart';
import '../models/debt_expense_entry.dart';
import '../providers/debt_expense_providers.dart';

class DebtExpenseEntryFormScreen extends ConsumerStatefulWidget {
  const DebtExpenseEntryFormScreen({super.key, required this.kind});
  final DebtExpenseKind kind;

  @override
  ConsumerState<DebtExpenseEntryFormScreen> createState() =>
      _DebtExpenseEntryFormScreenState();
}

class _DebtExpenseEntryFormScreenState
    extends ConsumerState<DebtExpenseEntryFormScreen> {
  final _title = TextEditingController();
  final _total = TextEditingController();
  final _paid = TextEditingController();
  final _note = TextEditingController();
  String? _category;
  StaffPaymentType _staffType = StaffPaymentType.salary;
  bool _staffPaid = true;
  DateTime? _dueDate;
  DateTime _entryDate = DateTime.now();
  bool _saving = false;

  DebtExpenseKind get _kind => widget.kind;
  bool get _isDebt => _kind == DebtExpenseKind.debt;
  bool get _isExpense => _kind == DebtExpenseKind.expense;
  bool get _isStaff => _kind == DebtExpenseKind.staffPayment;

  @override
  void dispose() {
    _title.dispose();
    _total.dispose();
    _paid.dispose();
    _note.dispose();
    super.dispose();
  }

  String get _appBarTitle => switch (_kind) {
        DebtExpenseKind.debt => AppStrings.deAddDebt,
        DebtExpenseKind.expense => AppStrings.deAddExpense,
        DebtExpenseKind.staffPayment => AppStrings.deAddStaff,
      };

  String get _titleLabel => switch (_kind) {
        DebtExpenseKind.debt => 'Kime / ne için',
        DebtExpenseKind.expense => 'Açıklama',
        DebtExpenseKind.staffPayment => 'Personel adı',
      };

  String get _titleHint => switch (_kind) {
        DebtExpenseKind.debt => 'Örn. Uncu Mehmet, Kira',
        DebtExpenseKind.expense => 'Örn. Elektrik faturası',
        DebtExpenseKind.staffPayment => 'Örn. Ahmet',
      };

  Future<void> _pickDate({required bool due}) async {
    final initial = due ? (_dueDate ?? DateTime.now()) : _entryDate;
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked == null) return;
    setState(() {
      if (due) {
        _dueDate = picked;
      } else {
        _entryDate = picked;
      }
    });
  }

  Future<void> _save() async {
    if (_saving) return;
    final title = _title.text.trim();
    if (!_isExpense && title.isEmpty) {
      _err('Lütfen ${_titleLabel.toLowerCase()} yaz.');
      return;
    }
    if (_isExpense && title.isEmpty && (_category ?? '').isEmpty) {
      _err('Açıklama veya kategori gir.');
      return;
    }
    final total = NumberFormatter.parseLoose(_total.text);
    if (total <= 0) {
      _err('Tutar sıfırdan büyük olmalı.');
      return;
    }
    // Kategori "Diğer" seçilip boş bırakılmışsa (debt/expense) engelle:
    // _category boş string ise (Diğer modu, manuel boş) uyarı.
    if (!_isStaff && _category != null && _category!.isEmpty) {
      _err('Kategori adını yaz.');
      return;
    }
    if (!AuthRequiredGuard.canWriteWithRef(ref)) {
      await showAuthRequiredSheet(context, ref);
      return;
    }

    final double paid;
    if (_isExpense) {
      paid = total; // gider = yapılmış harcama
    } else if (_isStaff) {
      paid = _staffPaid ? total : 0;
    } else {
      paid = NumberFormatter.parseLoose(_paid.text).clamp(0, total).toDouble();
    }

    final entry = DebtExpenseEntry(
      id: '',
      kind: _kind,
      title: title.isEmpty ? (_category ?? '') : title,
      category: _isStaff ? null : _category,
      totalAmount: total,
      paidAmount: paid,
      dueDate: _isDebt ? _dueDate : null,
      staffPaymentType: _isStaff ? _staffType : null,
      note: _note.text.trim().isEmpty ? null : _note.text.trim(),
      createdAt: _isDebt ? DateTime.now() : _entryDate,
    );

    setState(() => _saving = true);
    try {
      await ref.read(debtExpenseRepositoryProvider).addEntry(entry);
      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Kayıt eklendi.')),
      );
    } on GuestActionRequiredException {
      if (!mounted) return;
      await showAuthRequiredSheet(context, ref);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Kayıt eklenemedi. Tekrar dene.')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _err(String m) => ScaffoldMessenger.of(context)
      .showSnackBar(SnackBar(content: Text(m)));

  @override
  Widget build(BuildContext context) {
    return PremiumScaffold(
      appBar: AppBar(title: Text(_appBarTitle)),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.pageH,
            AppSpacing.s,
            AppSpacing.pageH,
            AppSpacing.xxl,
          ),
          children: [
            _label(_titleLabel),
            const SizedBox(height: 6),
            TextField(
              controller: _title,
              decoration: InputDecoration(hintText: _titleHint),
            ),
            const SizedBox(height: AppSpacing.l),

            // Kategori (debt/expense) — ProductChoiceChips "Diğer/manuel" ile.
            if (!_isStaff) ...[
              _label('Kategori'),
              const SizedBox(height: 8),
              ProductChoiceChips(
                selected: _category,
                onSelected: (v) => setState(() => _category = v),
                products: DebtExpenseCategories.forKind(_kind),
                otherFieldLabel: AppStrings.deCustomCategoryLabel,
                otherFieldHint: AppStrings.deCustomCategoryHint,
              ),
              const SizedBox(height: AppSpacing.l),
            ],

            // Personel ödeme tipi.
            if (_isStaff) ...[
              _label('İşlem tipi'),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final t in StaffPaymentType.values)
                    ChoiceChip(
                      label: Text(StaffPaymentLabels.of(t)),
                      selected: _staffType == t,
                      onSelected: (_) => setState(() => _staffType = t),
                      selectedColor: AppColors.brandLemon,
                      backgroundColor: AppColors.surfaceVariant,
                      side: BorderSide.none,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppRadius.m),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: AppSpacing.l),
            ],

            // Tutar.
            _label(_isDebt ? 'Toplam borç' : 'Tutar'),
            const SizedBox(height: 8),
            AppNumberField(label: 'Tutar', controller: _total, suffix: '₺'),
            const SizedBox(height: AppSpacing.l),

            // Borç: ödenen (opsiyonel).
            if (_isDebt) ...[
              _label('Ödenen tutar (opsiyonel)'),
              const SizedBox(height: 8),
              AppNumberField(
                  label: 'Ödenen', controller: _paid, suffix: '₺'),
              const SizedBox(height: AppSpacing.l),
            ],

            // Staff: ödendi / ödenecek.
            if (_isStaff) ...[
              SwitchListTile.adaptive(
                value: _staffPaid,
                onChanged: (v) => setState(() => _staffPaid = v),
                title: Text(_staffPaid ? 'Ödendi' : 'Ödenecek'),
                contentPadding: EdgeInsets.zero,
                activeThumbColor: AppColors.brandLemonPressed,
              ),
              const SizedBox(height: AppSpacing.s),
            ],

            // Tarih: borç → vade (opsiyonel); gider/personel → işlem tarihi.
            if (_isDebt)
              _DateRow(
                label: AppStrings.deDueDate,
                value: _dueDate,
                emptyText: AppStrings.deNoDueDate,
                onPick: () => _pickDate(due: true),
                onClear: _dueDate == null
                    ? null
                    : () => setState(() => _dueDate = null),
              )
            else
              _DateRow(
                label: 'Tarih',
                value: _entryDate,
                emptyText: '',
                onPick: () => _pickDate(due: false),
                onClear: null,
              ),
            const SizedBox(height: AppSpacing.l),

            _label('Not (opsiyonel)'),
            const SizedBox(height: 6),
            TextField(
              controller: _note,
              maxLines: 2,
              decoration: const InputDecoration(hintText: 'Kısa not…'),
            ),
            const SizedBox(height: AppSpacing.xl),
            AppPrimaryButton(
              label: 'Kaydet',
              icon: Icons.check_rounded,
              onPressed: _saving ? null : _save,
            ),
          ],
        ),
      ),
    );
  }

  Widget _label(String t) => Text(
        t,
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w800,
          color: AppColors.textPrimary,
        ),
      );
}

class _DateRow extends StatelessWidget {
  const _DateRow({
    required this.label,
    required this.value,
    required this.emptyText,
    required this.onPick,
    required this.onClear,
  });

  final String label;
  final DateTime? value;
  final String emptyText;
  final VoidCallback onPick;
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) {
    final text = value == null
        ? emptyText
        : '${value!.day.toString().padLeft(2, '0')}.${value!.month.toString().padLeft(2, '0')}.${value!.year}';
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
        ),
        if (onClear != null)
          IconButton(
            onPressed: onClear,
            icon: const Icon(Icons.close_rounded, size: 18),
            color: AppColors.textMuted,
          ),
        OutlinedButton.icon(
          onPressed: onPick,
          icon: const Icon(Icons.event_rounded, size: 16),
          label: Text(text.isEmpty ? 'Seç' : text),
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.brandInk,
            side: BorderSide(
              color: AppColors.brandLemonPressed.withValues(alpha: 0.5),
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadius.m),
            ),
          ),
        ),
      ],
    );
  }
}
