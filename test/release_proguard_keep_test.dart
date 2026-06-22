// FN-AUDIT-013 — Release ProGuard/R8 keep kuralları (kaynak-assertion).
//
// Minify/shrink açık release'te Firebase Messaging / Google Play Services
// reflection sınıfları kırpılırsa uygulama-dışı push CIHAZDA SESSİZCE çalışmaz.
// Bu test keep kurallarının repo'da kaldığını kilitler (gerçek shrink davranışı
// yalnız signing makinesinde cihaz smoke ile doğrulanır).

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final rules = File('android/app/proguard-rules.pro').readAsStringSync();

  group('FN-AUDIT-013 — Firebase/GMS ProGuard keep', () {
    test('Firebase keep + dontwarn mevcut', () {
      expect(rules.contains('-keep class com.google.firebase.** { *; }'), isTrue);
      expect(rules.contains('-dontwarn com.google.firebase.**'), isTrue);
    });

    test('Google Play Services keep + dontwarn mevcut', () {
      expect(
        rules.contains('-keep class com.google.android.gms.** { *; }'),
        isTrue,
      );
      expect(rules.contains('-dontwarn com.google.android.gms.**'), isTrue);
    });
  });
}
