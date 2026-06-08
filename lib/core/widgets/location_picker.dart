// FırınNet — controlled-data location picker (core/widgets).
//
// İl + ilçe seçimi searchable modal bottom sheet üzerinden yapılır.
// V1 Market M2'de marketplace tarafı için tanıtıldı; M6A'da core'a taşındı
// — profile, worker, job_seek + sonraki sprintlerde dealer/job_offer/bakery
// aynı widget'ı tüketir.
//
// Davranış:
//   * showProvincePicker → 81 il listesi (arama destekli) → seçilen
//     `TurkeyProvince` döner.
//   * showDistrictPicker → seçili ile bağlı ilçe listesi (arama destekli)
//     → seçilen `TurkeyDistrict` döner.
//   * İl seçilmeden ilçe seçimi yapılmaz (UI tarafı disable; helper de
//     null province'la çağrılırsa erken null döner).
//   * Türkçe büyük/küçük + ç ğ ı ş ü ö normalize aramayla eşleşir.

import 'package:flutter/material.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_tokens.dart';
import '../data/turkey_locations.dart';

class LocationPicker {
  const LocationPicker._();

  static Future<TurkeyProvince?> showProvincePicker(
    BuildContext context, {
    String? initialCode,
  }) {
    return showModalBottomSheet<TurkeyProvince>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.elevatedCard,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.l)),
      ),
      builder: (_) => _ProvinceSheet(initialCode: initialCode),
    );
  }

  static Future<TurkeyDistrict?> showDistrictPicker(
    BuildContext context, {
    required TurkeyProvince province,
    String? initialCode,
  }) {
    return showModalBottomSheet<TurkeyDistrict>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.elevatedCard,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.l)),
      ),
      builder: (_) =>
          _DistrictSheet(province: province, initialCode: initialCode),
    );
  }

  /// Türkçe → ASCII normalize + lower; arama eşlemesi için.
  static String normalize(String s) {
    final lower = s.toLowerCase();
    const tr = 'çğıöşüâîû';
    const en = 'cgiosuaiu';
    final buf = StringBuffer();
    for (var i = 0; i < lower.length; i++) {
      final ch = lower[i];
      final idx = tr.indexOf(ch);
      buf.write(idx >= 0 ? en[idx] : ch);
    }
    return buf.toString();
  }
}

class _ProvinceSheet extends StatefulWidget {
  const _ProvinceSheet({this.initialCode});
  final String? initialCode;
  @override
  State<_ProvinceSheet> createState() => _ProvinceSheetState();
}

class _ProvinceSheetState extends State<_ProvinceSheet> {
  final TextEditingController _q = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _q.dispose();
    super.dispose();
  }

  List<TurkeyProvince> _filtered() {
    if (_query.isEmpty) return TurkeyLocations.provinces;
    final n = LocationPicker.normalize(_query);
    return TurkeyLocations.provinces
        .where((p) => LocationPicker.normalize(p.name).contains(n))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final list = _filtered();
    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.only(bottom: mq.viewInsets.bottom),
        child: SizedBox(
          height: mq.size.height * 0.78,
          child: Column(
            children: [
              _SheetHeader(title: 'İl seç'),
              _SearchField(
                controller: _q,
                hint: 'İl ara (örn. İstanbul)',
                onChanged: (v) => setState(() => _query = v),
              ),
              const Divider(
                height: 1,
                thickness: 0.6,
                color: AppColors.borderHairline,
              ),
              Expanded(
                child: ListView.builder(
                  itemCount: list.length,
                  itemBuilder: (_, i) {
                    final p = list[i];
                    final selected = widget.initialCode == p.code;
                    return _SheetTile(
                      title: p.name,
                      subtitle: '${p.code} • ${p.districts.length} ilçe',
                      selected: selected,
                      onTap: () => Navigator.of(context).pop(p),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DistrictSheet extends StatefulWidget {
  const _DistrictSheet({required this.province, this.initialCode});
  final TurkeyProvince province;
  final String? initialCode;
  @override
  State<_DistrictSheet> createState() => _DistrictSheetState();
}

class _DistrictSheetState extends State<_DistrictSheet> {
  final TextEditingController _q = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _q.dispose();
    super.dispose();
  }

  List<TurkeyDistrict> _filtered() {
    if (_query.isEmpty) return widget.province.districts;
    final n = LocationPicker.normalize(_query);
    return widget.province.districts
        .where((d) => LocationPicker.normalize(d.name).contains(n))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final list = _filtered();
    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.only(bottom: mq.viewInsets.bottom),
        child: SizedBox(
          height: mq.size.height * 0.78,
          child: Column(
            children: [
              _SheetHeader(title: '${widget.province.name} • İlçe seç'),
              _SearchField(
                controller: _q,
                hint: 'İlçe ara',
                onChanged: (v) => setState(() => _query = v),
              ),
              const Divider(
                height: 1,
                thickness: 0.6,
                color: AppColors.borderHairline,
              ),
              Expanded(
                child: ListView.builder(
                  itemCount: list.length,
                  itemBuilder: (_, i) {
                    final d = list[i];
                    final selected = widget.initialCode == d.code;
                    return _SheetTile(
                      title: d.name,
                      subtitle: null,
                      selected: selected,
                      onTap: () => Navigator.of(context).pop(d),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SheetHeader extends StatelessWidget {
  const _SheetHeader({required this.title});
  final String title;
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.l,
        AppSpacing.m,
        AppSpacing.s,
        AppSpacing.s,
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w800,
                fontSize: 17,
              ),
            ),
          ),
          IconButton(
            onPressed: () => Navigator.of(context).maybePop(),
            icon: const Icon(Icons.close_rounded, color: AppColors.textPrimary),
          ),
        ],
      ),
    );
  }
}

class _SearchField extends StatelessWidget {
  const _SearchField({
    required this.controller,
    required this.hint,
    required this.onChanged,
  });
  final TextEditingController controller;
  final String hint;
  final ValueChanged<String> onChanged;
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.l,
        vertical: AppSpacing.s,
      ),
      child: TextField(
        controller: controller,
        onChanged: onChanged,
        decoration: InputDecoration(
          hintText: hint,
          prefixIcon: const Icon(Icons.search_rounded, size: 18),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppRadius.m),
          ),
          isDense: true,
        ),
      ),
    );
  }
}

class _SheetTile extends StatelessWidget {
  const _SheetTile({
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.onTap,
  });
  final String title;
  final String? subtitle;
  final bool selected;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.l,
          vertical: 12,
        ),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.softGold.withValues(alpha: 0.10)
              : Colors.transparent,
          border: const Border(
            bottom: BorderSide(color: AppColors.borderHairline, width: 0.4),
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: selected
                          ? AppColors.softGold
                          : AppColors.textPrimary,
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                    ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle!,
                      style: const TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (selected)
              const Icon(
                Icons.check_rounded,
                size: 18,
                color: AppColors.softGold,
              ),
          ],
        ),
      ),
    );
  }
}

/// Inline read-only field — Form veya filter sheet'te kullanılır.
/// Tap → modal picker; sıfırlamak için sağ `X` butonu.
class LocationPickerField extends StatelessWidget {
  const LocationPickerField({
    super.key,
    required this.label,
    required this.value,
    required this.onTap,
    this.onClear,
    this.enabled = true,
    this.hint,
  });

  final String label;
  final String? value;
  final VoidCallback onTap;
  final VoidCallback? onClear;
  final bool enabled;
  final String? hint;

  @override
  Widget build(BuildContext context) {
    final hasValue = value != null && value!.isNotEmpty;
    return InkWell(
      onTap: enabled ? onTap : null,
      borderRadius: BorderRadius.circular(AppRadius.s),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          enabled: enabled,
          suffixIcon: hasValue && onClear != null
              ? IconButton(
                  icon: const Icon(Icons.close_rounded, size: 18),
                  onPressed: onClear,
                )
              : Icon(
                  Icons.expand_more_rounded,
                  size: 20,
                  color: enabled ? AppColors.textPrimary : AppColors.textMuted,
                ),
        ),
        isEmpty: !hasValue,
        child: Text(
          hasValue ? value! : '',
          style: TextStyle(
            color: enabled ? AppColors.textPrimary : AppColors.textMuted,
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}
