// B2B Pazar — AsyncValue<List<T>> → liste/loading/error/empty tek tip render.
//
// Tüm B2B tab'ları repository'den FutureProvider ile veri alır; bu widget o
// AsyncValue'yu premium dilde gösterir: yükleniyor (spinner), hata
// (ErrorRetryState + yeniden dene), boş (verilen empty), veri (ListView).
// skipLoadingOnReload: write sonrası yenilemede eski içerik korunur, spinner
// flash olmaz. Supabase hatası ekranı çökertmez.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_tokens.dart';
import '../../../core/widgets/error_retry_state.dart';

class B2bAsyncList<T> extends StatelessWidget {
  const B2bAsyncList({
    super.key,
    required this.async,
    required this.itemBuilder,
    required this.empty,
    this.onRetry,
    this.padding = const EdgeInsets.fromLTRB(
      AppSpacing.pageH,
      AppSpacing.s,
      AppSpacing.pageH,
      AppSpacing.xxl,
    ),
    this.leading,
  });

  final AsyncValue<List<T>> async;
  final Widget Function(BuildContext context, T item) itemBuilder;
  final Widget empty;
  final VoidCallback? onRetry;
  final EdgeInsetsGeometry padding;

  /// Listenin en üstüne (ilk eleman olarak) eklenecek opsiyonel widget
  /// (ör. anonimlik notu). Boş listede de gösterilmez (yalnız veri varken).
  final Widget? leading;

  @override
  Widget build(BuildContext context) {
    return async.when(
      skipLoadingOnReload: true,
      skipLoadingOnRefresh: true,
      loading: () => const Center(
        child: Padding(
          padding: EdgeInsets.all(AppSpacing.xxl),
          child: CircularProgressIndicator(),
        ),
      ),
      error: (_, __) => ErrorRetryState(compact: true, onRetry: onRetry),
      data: (items) {
        if (items.isEmpty) return empty;
        final lead = leading;
        final count = items.length + (lead != null ? 1 : 0);
        return ListView.separated(
          physics: const BouncingScrollPhysics(
            parent: AlwaysScrollableScrollPhysics(),
          ),
          padding: padding,
          itemCount: count,
          separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.m),
          itemBuilder: (context, i) {
            if (lead != null && i == 0) return lead;
            final item = items[lead != null ? i - 1 : i];
            return itemBuilder(context, item);
          },
        );
      },
    );
  }
}
