import 'package:flutter/material.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_tokens.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/widgets/premium/firinnet_header.dart';
import '../../../core/widgets/premium/market_product_card.dart';
import '../../../core/widgets/premium/premium_scaffold.dart';
import '../../../core/widgets/premium/section_label.dart';

class MarketplaceScreen extends StatefulWidget {
  const MarketplaceScreen({super.key});

  @override
  State<MarketplaceScreen> createState() => _MarketplaceScreenState();
}

class _MarketplaceScreenState extends State<MarketplaceScreen> {
  static const _filters = <String>[
    'Tümü',
    'Hammadde',
    'Ekipman',
    'Devren Fırın',
    'İkinci El',
    'Ambalaj',
  ];

  static const _featured = _Product(
    title: 'Faal mahalle fırını — devren satılık',
    price: '₺ 850.000',
    city: 'Ankara · Çankaya',
    badge: 'Devren',
    seller: 'Çankaya Ekmek',
    note: '38 yıllık müşteri sirkülasyonu, tam donanımlı',
    gradient: [Color(0xFFF3E6D3), Color(0xFFE5D2B0)],
  );

  static const _items = <_Product>[
    _Product(
      title: 'Spiral mikser 80 L (paslanmaz, 3 hız)',
      price: '₺ 54.000',
      city: 'İstanbul · Bayrampaşa',
      badge: 'Ekipman',
      seller: 'Kara Endüstri',
      note: '2022, az kullanılmış',
      gradient: [Color(0xFFEDDDC4), Color(0xFFDFCCA8)],
    ),
    _Product(
      title: 'Tip 550 ekstra un · 25 kg paket',
      price: '₺ 780',
      city: 'Konya',
      badge: 'Hammadde',
      seller: 'Konya Değirmen',
      note: 'Yeni hasat, protein 13.2',
      gradient: [Color(0xFFF2E2C6), Color(0xFFE4D0AC)],
    ),
    _Product(
      title: 'Döner katlı taş tabanlı pide fırını',
      price: '₺ 180.000',
      city: 'Bursa · Osmangazi',
      badge: 'İkinci El',
      seller: 'Mehmet Usta',
      note: '5 katlı, 1.4 m² tabla',
      gradient: [Color(0xFFF5E8CF), Color(0xFFE8D6AE)],
    ),
    _Product(
      title: 'Hamur yoğurma robotu 25 L',
      price: '₺ 32.500',
      city: 'İzmir · Karşıyaka',
      badge: 'Ekipman',
      seller: 'Egem Ekipman',
      note: 'Servis bakımı yapıldı',
      gradient: [Color(0xFFEEE0C4), Color(0xFFE0CDA8)],
    ),
    _Product(
      title: 'Kuru maya · 500 gr · vakumlu',
      price: '₺ 195',
      city: 'İzmir',
      badge: 'Hammadde',
      seller: 'Ege Mayacılık',
      note: 'Yeni parti, son kullanma 2027',
      gradient: [Color(0xFFF3E5C8), Color(0xFFE6D2A8)],
    ),
    _Product(
      title: 'Susam · doğal · 5 kg',
      price: '₺ 1.450',
      city: 'Şanlıurfa',
      badge: 'Hammadde',
      seller: 'Urfa Susam',
      note: 'Beyaz / yıkanmış',
      gradient: [Color(0xFFEEDDC0), Color(0xFFE0CBA4)],
    ),
  ];

  int _filterIndex = 0;
  final TextEditingController _searchCtrl = TextEditingController();

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return PremiumScaffold(
      body: SafeArea(
        bottom: false,
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(
            parent: AlwaysScrollableScrollPhysics(),
          ),
          slivers: [
            const SliverToBoxAdapter(
              child: FirinNetHeader(
                title: AppStrings.marketTitle,
                subtitle: AppStrings.marketSubtitle,
                actions: [
                  HeaderActionButton(
                    icon: Icons.tune_rounded,
                    onTap: _noop,
                  ),
                ],
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.pageH,
                  AppSpacing.xs,
                  AppSpacing.pageH,
                  AppSpacing.s,
                ),
                child: TextField(
                  controller: _searchCtrl,
                  textInputAction: TextInputAction.search,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textPrimary,
                  ),
                  decoration: const InputDecoration(
                    hintText: AppStrings.marketSearchHint,
                    prefixIcon: Icon(
                      Icons.search_rounded,
                      color: AppColors.softGold,
                    ),
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: AppSpacing.l,
                      vertical: 14,
                    ),
                  ),
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: SizedBox(
                height: 44,
                child: ListView.separated(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.pageH,
                  ),
                  scrollDirection: Axis.horizontal,
                  itemCount: _filters.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (_, i) {
                    final selected = i == _filterIndex;
                    return ChoiceChip(
                      label: Text(_filters[i]),
                      selected: selected,
                      onSelected: (_) =>
                          setState(() => _filterIndex = i),
                    );
                  },
                ),
              ),
            ),
            const SliverToBoxAdapter(
              child: SectionLabel(title: AppStrings.marketSectionFeatured),
            ),
            SliverPadding(
              padding:
                  const EdgeInsets.symmetric(horizontal: AppSpacing.pageH),
              sliver: SliverToBoxAdapter(
                child: MarketProductCard(
                  title: _featured.title,
                  price: _featured.price,
                  city: _featured.city,
                  badge: _featured.badge,
                  seller: _featured.seller,
                  note: _featured.note,
                  imageGradient: _featured.gradient,
                  featured: true,
                ),
              ),
            ),
            const SliverToBoxAdapter(
              child: SectionLabel(
                title: AppStrings.marketSectionFresh,
                trailingLabel: AppStrings.feedSectionAll,
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.pageH,
                0,
                AppSpacing.pageH,
                AppSpacing.l,
              ),
              sliver: SliverGrid(
                gridDelegate:
                    const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  mainAxisSpacing: AppSpacing.m,
                  crossAxisSpacing: AppSpacing.m,
                  childAspectRatio: 0.62,
                ),
                delegate: SliverChildBuilderDelegate(
                  (_, i) {
                    final p = _items[i];
                    return MarketProductCard(
                      title: p.title,
                      price: p.price,
                      city: p.city,
                      badge: p.badge,
                      seller: p.seller,
                      imageGradient: p.gradient,
                    );
                  },
                  childCount: _items.length,
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.pageH,
                  AppSpacing.s,
                  AppSpacing.pageH,
                  AppSpacing.xxl,
                ),
                child: Container(
                  padding: const EdgeInsets.all(AppSpacing.m),
                  decoration: BoxDecoration(
                    color: AppColors.surface.withValues(alpha: 0.6),
                    borderRadius: BorderRadius.circular(AppRadius.m),
                    border: Border.all(
                      color: AppColors.borderHairline,
                      width: 0.6,
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.bolt_outlined,
                        size: 16,
                        color: AppColors.softGold,
                      ),
                      const SizedBox(width: AppSpacing.s),
                      Expanded(
                        child: Text(
                          AppStrings.marketHintV2,
                          style: theme.textTheme.bodySmall?.copyWith(
                            height: 1.4,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

void _noop() {}

class _Product {
  const _Product({
    required this.title,
    required this.price,
    required this.city,
    required this.badge,
    required this.seller,
    required this.gradient,
    this.note,
  });
  final String title;
  final String price;
  final String city;
  final String badge;
  final String seller;
  final String? note;
  final List<Color> gradient;
}
