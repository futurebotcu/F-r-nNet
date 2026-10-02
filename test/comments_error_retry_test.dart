// Final audit P1 — Yorum listesi hatası statik metin değil: Tekrar dene
// provider'ı yeniden ister ve liste kurtulur.

import 'package:firin_defter/core/constants/app_strings.dart';
import 'package:firin_defter/features/auth/providers/auth_providers.dart';
import 'package:firin_defter/features/auth/providers/can_write_check_provider.dart';
import 'package:firin_defter/features/social/comments/comments_page.dart';
import 'package:firin_defter/features/social/models/social_comment.dart';
import 'package:firin_defter/features/social/providers/social_providers.dart';
import 'package:firin_defter/features/social/repositories/local_social_comments_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _FlakyCommentsRepo extends LocalSocialCommentsRepository {
  int calls = 0;

  @override
  Future<List<SocialComment>> listComments(String postId) async {
    calls++;
    if (calls == 1) throw Exception('SocketException: offline');
    return super.listComments(postId);
  }
}

void main() {
  testWidgets('yorum yükleme hatası → Tekrar dene → liste yeniden istenir', (
    tester,
  ) async {
    final repo = _FlakyCommentsRepo();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          socialCommentsRepositoryProvider.overrideWithValue(repo),
          canWriteCheckProvider.overrideWithValue(() => false),
          currentAuthUserProvider.overrideWith((ref) => null),
        ],
        child: const MaterialApp(home: SocialCommentsPage(postId: 'p1')),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('comments_error_retry')), findsOneWidget);
    expect(find.textContaining('SocketException'), findsNothing);

    await tester.tap(find.text(AppStrings.retry));
    await tester.pumpAndSettle();
    expect(repo.calls, 2);
    expect(find.byKey(const ValueKey('comments_error_retry')), findsNothing);
  });
}
