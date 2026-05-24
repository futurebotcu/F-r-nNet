// Adapted from evan361425/flutter-pos-system
// commit 354e0417a3f3c85789084d88ed6ecd2e28d7d73d, Apache-2.0.
// See THIRD_PARTY_LICENSES.md.
//
// Modified for FırınNet (Sprint 6C, 2026-05-24):
// - Renamed `CheckoutCashierCalculator` → `CashTenderedCalculator`
// - Original path: lib/ui/order/checkout/checkout_cashier_calculator.dart
// - New path:      lib/features/dealers/widgets/cash_tendered_calculator.dart
// - Imports swapped to FırınNet helpers: `AppStrings`, `NumberFormatter`,
//   `AppColors`, `AppSpacing` (donor used `S.*` translator + `.toCurrency`/
//   `.toCurrencyLong` extensions + `CurrencySetting.instance.ceil` +
//   `kFABSpacing`).
// - `CurrencySetting.instance.ceil(price)` simplified to `ceilToDouble()`
//   (TR kuruş precision; donor's currency-aware ceil not needed).
// - Theme colors: operator buttons `AppColors.softGold` (donor used
//   `theme.colorScheme.secondary`); back/clear `AppColors.danger` (donor
//   used `theme.colorScheme.error`).
// - Core widget logic, keypad layout (5-column), state machine
//   (`isOperating`), `_calc` operator helper, and child classes
//   (`_CalculatorAction`, `_CalculatorPostfixAction`, `_SingleField`)
//   preserved verbatim from donor.

import 'package:flutter/material.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_tokens.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/utils/number_formatter.dart';

const _operators = ['+', '-', 'x'];

/// Nakit tahsilat / para üstü hesaplayıcı.
///
/// [price] borç tutarı (caller tarafından set edilir, widget değiştirmez).
/// [paid] verilen tutar (widget mutate eder; caller değer için izler).
/// [onSubmit] kullanıcı submit ettiğinde çağrılır. İçinde operatör varken
/// önce `=` davranışı tetiklenir; ikinci tap'te [onSubmit] fire eder.
class CashTenderedCalculator extends StatefulWidget {
  final VoidCallback onSubmit;
  final ValueNotifier<num> price;
  final ValueNotifier<num> paid;

  const CashTenderedCalculator({
    super.key,
    required this.onSubmit,
    required this.price,
    required this.paid,
  });

  @override
  State<CashTenderedCalculator> createState() =>
      _CashTenderedCalculatorState();
}

class _CashTenderedCalculatorState extends State<CashTenderedCalculator> {
  final paidState = GlobalKey<_SingleFieldState>();
  final changeState = GlobalKey<_SingleFieldState>();

  bool isOperating = false;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // avoid rounded border of accessor and causing overlapping.
        const SizedBox(height: 8.0),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Column(
            children: [
              _SingleField(
                key: paidState,
                id: 'cashier.calculator.paid',
                prefix: AppStrings.cashCalcLabelPaid,
                defaultText: NumberFormatter.currency(widget.price.value),
                errorText: '',
              ),
              const Divider(),
              _SingleField(
                key: changeState,
                id: 'cashier.calculator.change',
                prefix: AppStrings.cashCalcLabelChange,
                defaultText: '0',
                errorText: AppStrings.cashCalcInsufficient,
              ),
              const Divider(),
            ],
          ),
        ),
        Expanded(
          child: Center(
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.xl),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _CalculatorPostfixAction(action: _execPostfix, text: '1'),
                        _CalculatorPostfixAction(action: _execPostfix, text: '4'),
                        _CalculatorPostfixAction(action: _execPostfix, text: '7'),
                        _CalculatorPostfixAction(action: _execPostfix, text: '00'),
                      ],
                    ),
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _CalculatorPostfixAction(action: _execPostfix, text: '2'),
                        _CalculatorPostfixAction(action: _execPostfix, text: '5'),
                        _CalculatorPostfixAction(action: _execPostfix, text: '8'),
                        _CalculatorPostfixAction(action: _execPostfix, text: '0'),
                      ],
                    ),
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _CalculatorPostfixAction(action: _execPostfix, text: '3'),
                        _CalculatorPostfixAction(action: _execPostfix, text: '6'),
                        _CalculatorPostfixAction(action: _execPostfix, text: '9'),
                        _CalculatorAction(
                          key: const Key('cashier.calculator.dot'),
                          action: _execDot,
                          child: const Text('.'),
                        ),
                      ],
                    ),
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _CalculatorAction(
                          key: const Key('cashier.calculator.plus'),
                          action: () => _addOperator('+'),
                          color: AppColors.softGold,
                          child: const Icon(Icons.add_outlined, size: 24),
                        ),
                        _CalculatorAction(
                          key: const Key('cashier.calculator.minus'),
                          action: () => _addOperator('-'),
                          color: AppColors.softGold,
                          child: const Icon(Icons.remove_outlined, size: 24),
                        ),
                        _CalculatorAction(
                          key: const Key('cashier.calculator.times'),
                          action: () => _addOperator('x'),
                          color: AppColors.softGold,
                          child: const Icon(Icons.clear_outlined, size: 24),
                        ),
                        _CalculatorAction(
                          key: const Key('cashier.calculator.ceil'),
                          action: _execCeil,
                          color: AppColors.softGold,
                          child: const Icon(Icons.merge_type_rounded, size: 24),
                        ),
                      ],
                    ),
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _CalculatorAction(
                          key: const Key('cashier.calculator.back'),
                          action: _execBack,
                          color: AppColors.danger,
                          child: const Icon(Icons.arrow_back_rounded, size: 24),
                        ),
                        _CalculatorAction(
                          key: const Key('cashier.calculator.clear'),
                          action: _execClear,
                          color: AppColors.danger,
                          child: const Icon(Icons.refresh_outlined, size: 24),
                        ),
                        _CalculatorAction(
                          key: const Key('cashier.calculator.submit'),
                          action: _execSubmit,
                          height: 124,
                          child: isOperating
                              ? const Text('=')
                              : const Icon(Icons.check_outlined, size: 24),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  @override
  void initState() {
    super.initState();
    widget.paid.addListener(_onNotify);
  }

  @override
  void dispose() {
    widget.paid.removeListener(_onNotify);
    super.dispose();
  }

  String get text => paidState.currentState?.text ?? '';

  set text(String value) {
    String? changeText = '';

    if (value.isNotEmpty) {
      final paid = _calc(value);
      final change = paid - widget.price.value;

      changeText = change >= 0 ? NumberFormatter.currency(change) : null;
      widget.paid.value = paid;
    } else {
      widget.paid.value = widget.price.value;
    }

    paidState.currentState?.text = value;
    changeState.currentState?.text = changeText;
  }

  void _addOperator(String operator) {
    if (text.isNotEmpty) {
      // İç metin formatı parse-edilebilir olmalı (`num.tryParse` uyumlu);
      // bu yüzden `.toString()` (örn. "5", "5.5") — `NumberFormatter.currency`
      // değil (₺/virgül parse'ı bozar).
      text = _calc(text).toString() + operator;
      setState(() {
        isOperating = true;
      });
    }
  }

  void _execCeil() {
    final price = _calc(text, widget.price.value.toInt());
    // Donor uses currency-aware ceil; TR kuruş için sade `ceilToDouble`
    // yeterli (price.toDouble().ceilToDouble()).
    final ceilPrice = price.toDouble().ceilToDouble();
    text = ceilPrice.toString();
  }

  void _execBack() {
    if (text.isNotEmpty) {
      text = text.substring(0, text.length - 1);
      setState(() {
        isOperating = _operators.any((o) => text.contains(o));
      });
    }
  }

  void _execClear() {
    text = '';
    setState(() {
      isOperating = false;
    });
  }

  void _execSubmit() {
    if (isOperating) {
      setState(() {
        isOperating = false;
      });
      // İç metin formatı parse-edilebilir olmalı.
      text = _calc(text).toString();
    } else {
      widget.onSubmit();
    }
  }

  void _execDot() {
    if (text.isEmpty) {
      text = '0.';
      return;
    }

    if (!text.contains('.')) {
      text = '$text.';
    }
  }

  void _execPostfix(String postfix) {
    text = text + postfix;
  }

  num _calc(String val, [num other = 0]) {
    final fallback = num.tryParse(val) ?? other;
    try {
      final op = _operators.firstWhere((o) => val.contains(o));
      final parts = val
          .split(op)
          .map((e) => num.tryParse(e))
          .map((e) => e ?? (op == 'x' ? 1 : 0))
          .toList();

      return switch (op) {
        '+' => parts[0] + parts[1],
        '-' => parts[0] - parts[1],
        'x' || _ => parts[0] * parts[1],
      };
    } on StateError {
      return fallback;
    }
  }

  _onNotify() {
    // Parent paid notifier'ı dışarıdan değiştirirse text'i yeniden render et.
    // Donor `.toCurrencyLong()` parseable string döner; bizim
    // `NumberFormatter.currency` ₺ + virgül içerdiği için parse'ı bozar.
    // Sade `.toString()` calculator iç metin formatı için doğru.
    text = widget.paid.value.toString();
  }
}

class _CalculatorAction extends StatelessWidget {
  final VoidCallback action;
  final double height;
  final Color? color;
  final Widget child;

  const _CalculatorAction({
    super.key,
    required this.action,
    required this.child,
    this.height = 60,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(2),
      child: SizedBox(
        width: 60,
        height: height,
        child: OutlinedButton(
          style: OutlinedButton.styleFrom(
            foregroundColor: color,
            padding: EdgeInsets.zero,
          ),
          onPressed: action,
          child: child,
        ),
      ),
    );
  }
}

class _CalculatorPostfixAction extends StatelessWidget {
  final void Function(String) action;
  final String text;

  const _CalculatorPostfixAction({required this.action, required this.text});

  @override
  Widget build(BuildContext context) {
    return _CalculatorAction(
      key: Key('cashier.calculator.$text'),
      action: () => action(text),
      child: Text(text),
    );
  }
}

class _SingleField extends StatefulWidget {
  final String prefix;
  final String defaultText;
  final String errorText;
  final String id;

  const _SingleField({
    super.key,
    required this.id,
    required this.prefix,
    required this.defaultText,
    required this.errorText,
  });

  @override
  State<_SingleField> createState() => _SingleFieldState();
}

class _SingleFieldState extends State<_SingleField> {
  String? _text = '';

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(widget.prefix),
        const Spacer(),
        _text == null
            ? Text(widget.errorText, key: Key('${widget.id}.error'))
            : _text!.isEmpty
                ? Text(widget.defaultText, key: Key('${widget.id}.hint'))
                : Text(_text!, key: Key(widget.id)),
      ],
    );
  }

  String? get text => _text;

  set text(String? value) {
    setState(() => _text = value);
  }
}
