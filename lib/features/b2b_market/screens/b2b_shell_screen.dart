// B2B Pazar — native modül shell.
//
// /pazar route'unun kök ekranı. Rol [b2bRoleProvider] ile profilden otomatik
// çözülür; kullanıcıya rol değiştirme UI'ı YOKTUR. Role göre doğru sekme seti
// ve sade header alt metni gösterilir (önizleme/demo metni yok).
//
// Tedarikçi:  Mağazam · Ürünler · Kampanyalar · Teklif Ağı
// Alıcı:      Ürünler · Kampanyalar · Tedarikçiler · Tekliflerim

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_colors.dart';
import '../../../core/widgets/premium/firinnet_header.dart';
import '../../../core/widgets/premium/premium_scaffold.dart';
import '../../../core/widgets/segment_tab_bar.dart';
import '../../notifications/widgets/notifications_header_action.dart';
import '../providers/b2b_providers.dart';
import 'buyer/buyer_campaigns_tab.dart';
import 'buyer/buyer_products_tab.dart';
import 'buyer/buyer_quotes_tab.dart';
import 'buyer/buyer_suppliers_tab.dart';
import 'supplier/supplier_campaigns_tab.dart';
import 'supplier/supplier_offer_network_tab.dart';
import 'supplier/supplier_products_tab.dart';
import 'supplier/supplier_store_tab.dart';

class B2bShellScreen extends ConsumerStatefulWidget {
  const B2bShellScreen({super.key});

  @override
  ConsumerState<B2bShellScreen> createState() => _B2bShellScreenState();
}

class _B2bShellScreenState extends ConsumerState<B2bShellScreen> {
  int _segment = 0;
  Set<int> _visited = <int>{0};

  static const _supplierLabels = <String>[
    'Mağazam',
    'Ürünler',
    'Kampanyalar',
    'Teklif Ağı',
  ];
  static const _buyerLabels = <String>[
    'Ürünler',
    'Kampanyalar',
    'Tedarikçiler',
    'Tekliflerim',
  ];

  void _select(int i) {
    if (i == _segment) return;
    setState(() {
      _segment = i;
      _visited.add(i);
    });
  }

  void _resetSegments() {
    setState(() {
      _segment = 0;
      _visited = <int>{0};
    });
  }

  @override
  Widget build(BuildContext context) {
    final role = ref.watch(b2bRoleProvider);
    // Rol (profil) oturum içinde değişirse segmenti başa al — tab seti değişir.
    ref.listen<B2bRole>(b2bRoleProvider, (_, __) => _resetSegments());

    final isSupplier = role == B2bRole.supplier;
    final labels = isSupplier ? _supplierLabels : _buyerLabels;

    return PremiumScaffold(
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            FirinNetHeader(
              title: 'Pazar',
              subtitle: role.headerSubtitle,
              actions: const [NotificationsHeaderAction()],
            ),
            const Divider(height: 1, color: AppColors.borderHairline),
            SegmentTabBar(
              labels: labels,
              index: _segment,
              onChanged: _select,
            ),
            Expanded(
              child: IndexedStack(
                index: _segment,
                children: isSupplier ? _supplierTabs() : _buyerTabs(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _supplierTabs() => [
        _lazy(0, const SupplierStoreTab()),
        _lazy(1, const SupplierProductsTab()),
        _lazy(2, const SupplierCampaignsTab()),
        _lazy(3, const SupplierOfferNetworkTab()),
      ];

  List<Widget> _buyerTabs() => [
        _lazy(0, const BuyerProductsTab()),
        _lazy(1, const BuyerCampaignsTab()),
        _lazy(2, const BuyerSuppliersTab()),
        _lazy(3, const BuyerQuotesTab()),
      ];

  Widget _lazy(int index, Widget child) =>
      _visited.contains(index) ? child : const SizedBox.shrink();
}
