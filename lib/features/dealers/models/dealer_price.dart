/// Bir bayinin belirli bir ürün için geçerli birim fiyatı.
/// Aynı bayi+ürün için farklı `validFrom` tarihleri olabilir;
/// "şu an geçerli" olan en son tarihli kayıttır.
///
/// Supabase şeması:
/// dealer_prices(id, dealer_id, product_name, unit_price, valid_from, note)
class DealerPrice {
  const DealerPrice({
    required this.id,
    required this.dealerId,
    required this.productName,
    required this.unitPrice,
    required this.validFrom,
    this.note = '',
  });

  final String id;
  final String dealerId;
  final String productName;
  final double unitPrice;
  final DateTime validFrom;
  final String note;
}
