import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_tokens.dart';
import '../../../../core/widgets/app_primary_button.dart';
import '../../../../core/widgets/premium/premium_card.dart';
import '../../../../core/widgets/premium/premium_scaffold.dart';

/// Hesaplama modül ekranları için ortak iskelet.
///
/// Üstte opsiyonel ipucu, ardından girdi alanları, "Hesapla" butonu ve
/// (varsa) sonuç bölümü. Matematik/iş mantığı içermez — yalnız düzen verir;
/// her modül kendi girdi widget'larını ve sonuç widget'ını besler.
class CalculatorFormScaffold extends StatefulWidget {
  const CalculatorFormScaffold({
    super.key,
    required this.title,
    required this.inputs,
    required this.onCalculate,
    this.result,
    this.hint,
    this.calculateLabel = 'Hesapla',
  });

  final String title;
  final List<Widget> inputs;
  final VoidCallback onCalculate;

  /// Sonuç bölümü — null ise henüz hesaplanmadı.
  final Widget? result;
  final String? hint;
  final String calculateLabel;

  @override
  State<CalculatorFormScaffold> createState() => _CalculatorFormScaffoldState();
}

class _CalculatorFormScaffoldState extends State<CalculatorFormScaffold> {
  final ScrollController _scrollController = ScrollController();
  final GlobalKey _resultKey = GlobalKey();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  /// Hesapla'ya basınca: önce hesabı çalıştır (parent setState), sonra bir
  /// frame sonra sonuç bölümünü görünür yap. Çok inputlu ekranlarda sonuç
  /// aşağıda kalmasın; kullanıcı sonuca götürülsün. Sonuç yoksa kaydırma yok.
  void _handleCalculate() {
    widget.onCalculate();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final ctx = _resultKey.currentContext;
      if (ctx != null) {
        Scrollable.ensureVisible(
          ctx,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
          alignment: 0.0,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return PremiumScaffold(
      appBar: AppBar(title: Text(widget.title)),
      body: SafeArea(
        child: ListView(
          controller: _scrollController,
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.pageH,
            AppSpacing.m,
            AppSpacing.pageH,
            AppSpacing.xxl,
          ),
          children: [
            if (widget.hint != null) ...[
              _Hint(text: widget.hint!),
              const SizedBox(height: AppSpacing.l),
            ],
            for (var i = 0; i < widget.inputs.length; i++) ...[
              widget.inputs[i],
              if (i != widget.inputs.length - 1)
                const SizedBox(height: AppSpacing.s),
            ],
            const SizedBox(height: AppSpacing.l),
            AppPrimaryButton(
              label: widget.calculateLabel,
              icon: Icons.calculate_rounded,
              onPressed: _handleCalculate,
            ),
            if (widget.result != null) ...[
              const SizedBox(height: AppSpacing.xl),
              KeyedSubtree(
                key: _resultKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [const _ResultSectionLabel(), widget.result!],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _Hint extends StatelessWidget {
  const _Hint({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    return PremiumCard(
      padding: const EdgeInsets.all(AppSpacing.m),
      child: Row(
        children: [
          const Icon(Icons.bolt_rounded, color: AppColors.softGold, size: 18),
          const SizedBox(width: AppSpacing.s),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 13.5,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ResultSectionLabel extends StatelessWidget {
  const _ResultSectionLabel();

  @override
  Widget build(BuildContext context) {
    // İnce ayırıcı + belirgin başlık: sonuç, uzun input listesinden görsel
    // olarak net ayrışır.
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(height: 1, color: AppColors.borderHairline),
        const SizedBox(height: AppSpacing.m),
        const Padding(
          padding: EdgeInsets.fromLTRB(2, 0, 0, AppSpacing.s),
          child: Text(
            'SONUÇ',
            style: TextStyle(
              color: AppColors.softGold,
              fontWeight: FontWeight.w800,
              fontSize: 12.5,
              letterSpacing: 1.4,
            ),
          ),
        ),
      ],
    );
  }
}
