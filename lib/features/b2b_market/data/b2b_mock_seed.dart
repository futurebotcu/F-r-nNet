// B2B Pazar — mock seed verisi (preview sprint).
//
// Tamamen statik, deterministik mock. Supabase / backend / migration YOK.
// Tüm tarih/sayılar sabit string; Date.now() veya random kullanılmaz.
//
// Sahiplik kuralı: [B2bMockSeed.mySupplierId] preview "tedarikçi" mağazasıdır;
// bu id'ye ait ürün/kampanyalar isMine=true taşır → "Benim ürünüm / kampanyam".
// "Tekliflerim" ise createdByMe=true olan teklif talepleridir (alıcı preview).

import '../models/b2b_campaign.dart';
import '../models/b2b_product.dart';
import '../models/b2b_quote_reply.dart';
import '../models/b2b_quote_request.dart';
import '../models/b2b_store.dart';

class B2bMockSeed {
  const B2bMockSeed._();

  /// Preview tedarikçinin mağaza id'si (sahiplik referansı).
  static const String mySupplierId = 's1';

  // ---- Kategoriler (ürün filtre chip'leri) ----
  static const List<String> productCategories = <String>[
    'Un',
    'Maya',
    'Katkı',
    'Yağ',
    'Ambalaj',
    'Ekipman',
  ];

  // ---- Mağazalar (tedarikçi vitrinleri) ----
  static const List<B2bStore> stores = <B2bStore>[
    B2bStore(
      id: 's1',
      name: 'Anadolu Un & Maya',
      monogram: 'AU',
      tagline: 'Tam buğday ve özel tip unlarda toptan tedarik',
      description:
          'Konya merkezli değirmenimizden fırınlara doğrudan un ve yaş maya '
          'tedariki. Düzenli teslimat ve toplu alımda esnek koşullar.',
      categories: <String>['Un', 'Maya', 'Katkı'],
      serviceRegions: <String>['İç Anadolu', 'Marmara'],
      productCount: 6,
      campaignCount: 2,
      isMine: true,
    ),
    B2bStore(
      id: 's2',
      name: 'Marmara Gıda Toptan',
      monogram: 'MG',
      tagline: 'Margarin, sıvı yağ ve fırın katkıları',
      description:
          'Fırın ve pastanelere yağ grubu ve katkı çözümleri. İstanbul içi '
          'aynı gün, Marmara geneli ertesi gün teslimat.',
      categories: <String>['Yağ', 'Katkı'],
      serviceRegions: <String>['Marmara'],
      productCount: 5,
      campaignCount: 1,
    ),
    B2bStore(
      id: 's3',
      name: 'Ege Ambalaj',
      monogram: 'EA',
      tagline: 'Ekmek poşeti, kraft kese ve özel baskı ambalaj',
      description:
          'Fırın ambalajında toplu üretim. Logolu baskı ve standart ürünlerde '
          'geniş stok.',
      categories: <String>['Ambalaj'],
      serviceRegions: <String>['Ege', 'Marmara'],
      productCount: 4,
      campaignCount: 1,
    ),
    B2bStore(
      id: 's4',
      name: 'Toros Maya',
      monogram: 'TM',
      tagline: 'Yaş ve kuru maya üretimi',
      description:
          'Akdeniz bölgesine yaş maya ve instant kuru maya tedariki. Soğuk '
          'zincir teslimat.',
      categories: <String>['Maya'],
      serviceRegions: <String>['Akdeniz'],
      productCount: 3,
      campaignCount: 0,
    ),
    B2bStore(
      id: 's5',
      name: 'Fırın Ekipman Merkezi',
      monogram: 'FE',
      tagline: 'Fırın, hamur ekipmanı ve yedek parça',
      description:
          'Yeni ve yenilenmiş fırın ekipmanı, tava ve tepsi grubu. Kurulum ve '
          'servis desteği.',
      categories: <String>['Ekipman'],
      serviceRegions: <String>['Tüm Türkiye'],
      productCount: 4,
      campaignCount: 1,
    ),
  ];

  // ---- Ürünler (genel B2B ürün pazarı — tüm tedarikçiler) ----
  static const List<B2bProduct> products = <B2bProduct>[
    B2bProduct(
      id: 'p1',
      name: 'Tam Buğday Unu (Tip 850)',
      supplierId: 's1',
      supplierName: 'Anadolu Un & Maya',
      category: 'Un',
      minOrder: '50 çuval',
      deliveryRegion: 'İç Anadolu, Marmara',
      isMine: true,
    ),
    B2bProduct(
      id: 'p2',
      name: 'Ekmeklik Un (Tip 650)',
      supplierId: 's1',
      supplierName: 'Anadolu Un & Maya',
      category: 'Un',
      minOrder: '100 çuval',
      deliveryRegion: 'İç Anadolu, Marmara',
      isMine: true,
    ),
    B2bProduct(
      id: 'p3',
      name: 'Yaş Maya (Blok)',
      supplierId: 's1',
      supplierName: 'Anadolu Un & Maya',
      category: 'Maya',
      minOrder: '20 koli',
      deliveryRegion: 'İç Anadolu',
      isMine: true,
    ),
    B2bProduct(
      id: 'p4',
      name: 'Fırın Margarini %80',
      supplierId: 's2',
      supplierName: 'Marmara Gıda Toptan',
      category: 'Yağ',
      minOrder: '40 koli',
      deliveryRegion: 'Marmara',
    ),
    B2bProduct(
      id: 'p5',
      name: 'Sıvı Ayçiçek Yağı (Teneke)',
      supplierId: 's2',
      supplierName: 'Marmara Gıda Toptan',
      category: 'Yağ',
      minOrder: '60 teneke',
      deliveryRegion: 'Marmara',
    ),
    B2bProduct(
      id: 'p6',
      name: 'Hamur Geliştirici Katkı',
      supplierId: 's2',
      supplierName: 'Marmara Gıda Toptan',
      category: 'Katkı',
      minOrder: '25 kg',
      deliveryRegion: 'Marmara',
    ),
    B2bProduct(
      id: 'p7',
      name: 'Kraft Ekmek Kesesi (Baskısız)',
      supplierId: 's3',
      supplierName: 'Ege Ambalaj',
      category: 'Ambalaj',
      minOrder: '10.000 adet',
      deliveryRegion: 'Ege, Marmara',
    ),
    B2bProduct(
      id: 'p8',
      name: 'Logolu Ekmek Poşeti (Özel Baskı)',
      supplierId: 's3',
      supplierName: 'Ege Ambalaj',
      category: 'Ambalaj',
      minOrder: '20.000 adet',
      deliveryRegion: 'Ege, Marmara',
    ),
    B2bProduct(
      id: 'p9',
      name: 'İnstant Kuru Maya',
      supplierId: 's4',
      supplierName: 'Toros Maya',
      category: 'Maya',
      minOrder: '30 koli',
      deliveryRegion: 'Akdeniz',
    ),
    B2bProduct(
      id: 'p10',
      name: 'Döner Tabanlı Kat Fırın (Yenilenmiş)',
      supplierId: 's5',
      supplierName: 'Fırın Ekipman Merkezi',
      category: 'Ekipman',
      minOrder: '1 adet',
      deliveryRegion: 'Tüm Türkiye',
    ),
    B2bProduct(
      id: 'p11',
      name: 'Endüstriyel Hamur Yoğurma Makinesi',
      supplierId: 's5',
      supplierName: 'Fırın Ekipman Merkezi',
      category: 'Ekipman',
      minOrder: '1 adet',
      deliveryRegion: 'Tüm Türkiye',
    ),
  ];

  // ---- Kampanyalar (tüm tedarikçiler — ticari fırsat) ----
  static const List<B2bCampaign> campaigns = <B2bCampaign>[
    B2bCampaign(
      id: 'c1',
      title: 'Toplu Un Alımında Sezon Fırsatı',
      supplierId: 's1',
      supplierName: 'Anadolu Un & Maya',
      category: 'Un',
      region: 'İç Anadolu, Marmara',
      minPurchase: '200 çuval ve üzeri',
      validUntil: '30 Haziran 2026',
      linkedProduct: 'Ekmeklik Un (Tip 650)',
      isMine: true,
    ),
    B2bCampaign(
      id: 'c2',
      title: 'Maya + Katkı Paket Tedarik',
      supplierId: 's1',
      supplierName: 'Anadolu Un & Maya',
      category: 'Maya',
      region: 'İç Anadolu',
      minPurchase: '50 koli maya',
      validUntil: '15 Temmuz 2026',
      isMine: true,
    ),
    B2bCampaign(
      id: 'c3',
      title: 'Margarin Grubunda Toplu İndirim',
      supplierId: 's2',
      supplierName: 'Marmara Gıda Toptan',
      category: 'Yağ',
      region: 'Marmara',
      minPurchase: '100 koli',
      validUntil: '20 Haziran 2026',
      linkedProduct: 'Fırın Margarini %80',
    ),
    B2bCampaign(
      id: 'c4',
      title: 'Baskılı Ambalajda Erken Sipariş',
      supplierId: 's3',
      supplierName: 'Ege Ambalaj',
      category: 'Ambalaj',
      region: 'Ege, Marmara',
      minPurchase: '50.000 adet',
      validUntil: '10 Temmuz 2026',
    ),
    B2bCampaign(
      id: 'c5',
      title: 'Yenilenmiş Ekipmanda Kurulum Dahil',
      supplierId: 's5',
      supplierName: 'Fırın Ekipman Merkezi',
      category: 'Ekipman',
      region: 'Tüm Türkiye',
      minPurchase: '1 adet ve üzeri',
      validUntil: '31 Ağustos 2026',
    ),
  ];

  // ---- Teklif Ağı (alıcıların açtığı ANONİM talepler) ----
  // Tedarikçinin gördüğü liste. İşletme adı/telefon/adres/kişi YOK.
  static const List<B2bQuoteRequest> openQuoteRequests = <B2bQuoteRequest>[
    B2bQuoteRequest(
      id: 'q1',
      productOrCategory: 'Ekmeklik Un (Tip 650)',
      quantity: '300 çuval / ay',
      city: 'İstanbul',
      district: 'Bağcılar',
      buyerType: 'Fırın',
      deliveryTime: 'Haftalık düzenli',
      note: 'Sürekli tedarikçi arıyoruz, numune talep edebiliriz.',
      status: B2bQuoteStatus.waiting,
    ),
    B2bQuoteRequest(
      id: 'q2',
      productOrCategory: 'Yaş Maya',
      quantity: '40 koli',
      city: 'Kocaeli',
      district: 'Gebze',
      buyerType: 'Fırın',
      deliveryTime: '2 hafta içinde',
      note: 'Soğuk zincir teslimat şart.',
      status: B2bQuoteStatus.waiting,
    ),
    B2bQuoteRequest(
      id: 'q3',
      productOrCategory: 'Logolu Ekmek Poşeti',
      quantity: '50.000 adet',
      city: 'İzmir',
      district: 'Bornova',
      buyerType: 'Pastane',
      deliveryTime: 'Bu ay sonu',
      note: 'Baskı için tasarım hazır.',
      status: B2bQuoteStatus.replied,
      replyCount: 2,
    ),
    B2bQuoteRequest(
      id: 'q4',
      productOrCategory: 'Fırın Margarini',
      quantity: '80 koli',
      city: 'Bursa',
      district: 'Nilüfer',
      buyerType: 'Fırın',
      deliveryTime: 'Esnek',
      note: '%80 yağ oranı tercih edilir.',
      status: B2bQuoteStatus.waiting,
    ),
    B2bQuoteRequest(
      id: 'q5',
      productOrCategory: 'Tam Buğday Unu',
      quantity: '120 çuval',
      city: 'Ankara',
      district: 'Çankaya',
      buyerType: 'Kafe / Restoran',
      deliveryTime: 'Aylık',
      note: 'Organik sertifika varsa öncelik.',
      status: B2bQuoteStatus.closed,
    ),
  ];

  // ---- Tekliflerim (alıcı preview'in kendi açtığı talepler) ----
  static const List<B2bQuoteRequest> myQuoteRequests = <B2bQuoteRequest>[
    B2bQuoteRequest(
      id: 'm1',
      productOrCategory: 'Ekmeklik Un (Tip 650)',
      quantity: '150 çuval',
      city: 'İstanbul',
      district: 'Esenler',
      buyerType: 'Fırın',
      deliveryTime: 'Haftalık',
      note: 'Düzenli tedarik için fiyat bekliyorum.',
      status: B2bQuoteStatus.replied,
      replyCount: 3,
      createdByMe: true,
    ),
    B2bQuoteRequest(
      id: 'm2',
      productOrCategory: 'Yaş Maya',
      quantity: '25 koli',
      city: 'İstanbul',
      district: 'Esenler',
      buyerType: 'Fırın',
      deliveryTime: '1 hafta içinde',
      note: '',
      status: B2bQuoteStatus.waiting,
      createdByMe: true,
    ),
    B2bQuoteRequest(
      id: 'm3',
      productOrCategory: 'Kraft Ekmek Kesesi',
      quantity: '10.000 adet',
      city: 'İstanbul',
      district: 'Esenler',
      buyerType: 'Fırın',
      deliveryTime: 'Bu ay',
      note: 'Baskısız standart ürün yeterli.',
      status: B2bQuoteStatus.closed,
      replyCount: 1,
      createdByMe: true,
    ),
  ];

  // ---- Teklif cevapları (mock — "Tekliflerim" cevap özetleri) ----
  static const List<B2bQuoteReply> replies = <B2bQuoteReply>[
    B2bQuoteReply(
      id: 'r1',
      requestId: 'm1',
      supplierName: 'Anadolu Un & Maya',
      message: 'Haftalık 150 çuval için sabit fiyat verebiliriz.',
      createdAtLabel: '2 saat önce',
      priceHint: '≈ ₺640 / çuval',
    ),
    B2bQuoteReply(
      id: 'r2',
      requestId: 'm1',
      supplierName: 'Marmara Gıda Toptan',
      message: 'Numune gönderebiliriz, teslimat Marmara geneli.',
      createdAtLabel: 'Dün',
    ),
  ];
}
