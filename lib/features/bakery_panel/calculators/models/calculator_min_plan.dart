/// Bir hesaplama aracını açan minimum ticari plan (Paywall UI V1).
///
/// Yalnız TİCARİ kullanıcıya uygulanır; bireysel/toptancı için kilit yok
/// (hub, hesap türü ticari değilse minPlan'ı yok sayar). Formüllere/servislere
/// dokunmaz — saf görünürlük/kilit metadatasıdır.
enum CalculatorMinPlan { free, pro, premium }
