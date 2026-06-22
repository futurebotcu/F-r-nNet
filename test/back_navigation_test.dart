// PR-UI-1 — Android geri tuşu / tab / push navigation kontratı.
// PopScope wiring + bildirim routing'i source-assertion ile kilitlenir
// (sistem back davranışı widget test'te güvenilir taklit edilemez).

import 'dart:io';

import 'package:firin_defter/features/notifications/notification_routing.dart';
import 'package:flutter_test/flutter_test.dart';

String _read(String p) => File(p).readAsStringSync();

void main() {
  group('UI-NAV-001 — AppShell back PopScope', () {
    final src = _read('lib/features/dashboard/screens/app_shell.dart');
    test('PopScope + ilk tab pop / diğer tab → ilk taba dön', () {
      expect(src.contains('PopScope'), isTrue);
      expect(src.contains('canPop: index == 0'), isTrue);
      expect(src.contains('context.go(_tabs.first.route)'), isTrue);
    });
  });

  group('UI-NAV-004 — mini-app shell iç tab back', () {
    test('dealer shell PopScope → tab 0 reset', () {
      final s = _read('lib/features/dealers/screens/dealer_shell_screen.dart');
      expect(s.contains('PopScope'), isTrue);
      expect(s.contains('canPop: index == 0'), isTrue);
      expect(s.contains('dealerShellTabIndexProvider.notifier).state = 0'), isTrue);
    });
    test('debt-expense shell PopScope → tab 0 reset', () {
      final s = _read(
        'lib/features/debt_expense/screens/debt_expense_shell_screen.dart',
      );
      expect(s.contains('PopScope'), isTrue);
      expect(s.contains('canPop: index == 0'), isTrue);
      expect(
        s.contains('debtExpenseShellTabIndexProvider.notifier).state = 0'),
        isTrue,
      );
    });
  });

  group('UI-NAV-002/003 — bildirim routing', () {
    test('shell kökü → go-safe; derin route → push-safe', () {
      // /messages artık doğru shell kökü (UI-NAV-003).
      expect(isShellTabRoot('/messages'), isTrue);
      expect(isShellTabRoot('/community'), isTrue);
      expect(isShellTabRoot('/panel'), isTrue);
      // Eski yanlış literal değil.
      expect(isShellTabRoot('/mesajlar'), isFalse);
      // Derin route → push (back-stack korunur).
      expect(isShellTabRoot('/pazar/tekliflerim/abc'), isFalse);
      expect(isShellTabRoot('/notifications'), isFalse);
      // Query string yok sayılır.
      expect(isShellTabRoot('/community?seg=groups'), isTrue);
    });

    test('navigateToNotificationRoute shell-kök/derin ayrımı yapar (kaynak)', () {
      final r = _read('lib/features/notifications/notification_routing.dart');
      expect(r.contains('isShellTabRoot(route)'), isTrue);
      expect(r.contains('router.go(route)'), isTrue);
      expect(r.contains('router.push(route)'), isTrue);
    });

    test('push servisi koşulsuz go yerine navigateToNotificationRoute kullanır',
        () {
      final p = _read(
        'lib/features/notifications/push/push_notification_service.dart',
      );
      expect(p.contains('navigateToNotificationRoute(router, route)'), isTrue);
      // Eski koşulsuz appRouter?.go(route) kalmamalı.
      expect(p.contains('appRouter?.go(route)'), isFalse);
    });
  });
}
