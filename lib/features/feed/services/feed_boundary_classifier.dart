// FırınNet Feed Boundary V1 — deterministic rule-based composer guard.
//
// Ürün kuralı: Feed = sektör sohbeti / soru / deneyim / gündem / topluluk.
// Feed ≠ ilan panosu / reklam panosu / satış panosu. Net ticari-ilan-satış
// sinyali taşıyan paylaşımlar doğru alana (Pazar / İş İlanları / İş yeri /
// Ekipman) yönlendirilir; küfür-dolandırıcılık içerikleri yayınlanmaz.
//
// Tasarım ilkeleri:
//   * AŞIRI agresif sansür YOK — "eleman bulmak zor", "hamur makinesi
//     alırken neye dikkat edilir?" gibi sohbet/soru daima serbest.
//   * Sinyal = niyet kalıbı (satılık/aranıyor/sipariş...) — domain ismi tek
//     başına asla yeterli değil.
//   * GÜÇLÜ kalıp → high (yönlendir/engelle). ZAYIF tek token → medium;
//     soru/tartışma işareti varsa → allowed (belirsiz sohbete izin),
//     yoksa ticari/ilan kategorilerinde yine yönlendir (ürün hedefi).
//   * AI/moderasyon servisi yok; saf Dart, deterministik, test edilebilir.

/// Yakalanan içerik kategorisi.
enum FeedBoundaryCategory {
  none,
  profanity,
  commercialAd,
  jobAd,
  jobSeek,
  workplaceSale,
  equipmentSale,
  scamOrIllegal,
}

/// Yönlendirme hedefi (UI route eşlemesi feed_boundary_sheet'te).
enum FeedBoundaryDestination {
  feedAllowed,
  market,
  jobListings,
  jobSeekListing,
  workplaceListings,
  equipmentListings,
  safetyRewrite,
}

enum FeedBoundaryConfidence { low, medium, high }

class FeedBoundaryResult {
  const FeedBoundaryResult({
    required this.allowed,
    this.category = FeedBoundaryCategory.none,
    this.confidence = FeedBoundaryConfidence.low,
    this.destination = FeedBoundaryDestination.feedAllowed,
    this.reason = '',
  });

  final bool allowed;
  final FeedBoundaryCategory category;
  final FeedBoundaryConfidence confidence;
  final FeedBoundaryDestination destination;

  /// Teşhis/log için kısa neden (kullanıcıya gösterilmez; copy sheet'te).
  final String reason;

  static const FeedBoundaryResult ok = FeedBoundaryResult(allowed: true);
}

class FeedBoundaryClassifier {
  const FeedBoundaryClassifier._();

  // ── Normalizasyon ─────────────────────────────────────────────────
  /// Türkçe-güvenli lowercase + ASCII-fold + noktalama → boşluk.
  ///
  /// ASCII-fold (ı→i, ş→s, ç→c, ğ→g, ö→o, ü→u) hem metne hem sinyallere
  /// uygulanır: "satilik", "araniyor" gibi ASCII yazımlar ve ı/i farkları
  /// sinyali ıskalamaz. (Saha kanıtı: "eleman aranyor" tipi yazımlar.)
  static String _asciiFold(String s) => s
      .replaceAll('ı', 'i')
      .replaceAll('ş', 's')
      .replaceAll('ç', 'c')
      .replaceAll('ğ', 'g')
      .replaceAll('ö', 'o')
      .replaceAll('ü', 'u');

  // Leet/dekorasyon haritası — s1kt1r, ar@nıyor, sat0lık gibi yazımlar.
  static const Map<String, String> _leetMap = {
    '0': 'o', '1': 'i', '3': 'e', '4': 'a', '5': 's', '7': 't',
    '@': 'a', r'$': 's', '!': 'i',
  };

  static String _normalize(String input) {
    var lowered = _asciiFold(
      input.replaceAll('İ', 'i').replaceAll('I', 'ı').toLowerCase(),
    );
    _leetMap.forEach((k, v) => lowered = lowered.replaceAll(k, v));
    var cleaned = lowered
        .replaceAll(RegExp(r'[^a-z?%]+'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    // Tekrarlanan harf sıkıştırma: "aranııııyor" → "aranıyor" (fold sonrası
    // "araniiiiyor" → "araniyor"). 2+ tekrar → tek harf.
    cleaned = cleaned.replaceAllMapped(
      RegExp(r'([a-z])\1{2,}'),
      (m) => m.group(1)!,
    );
    return ' $cleaned ';
  }

  /// Parça birleştirilmiş form — YALNIZ küfür kontrolünde kullanılır:
  /// "s-keym"/"s keym" → "skeym". Düz formda kullanılmaz çünkü legit kısa
  /// kelimeleri ("iş", "bu") komşusuna yapıştırıp faz eşleşmesini bozar.
  static String _glued(String norm) {
    final tokens = norm.trim().split(' ');
    final out = <String>[];
    var i = 0;
    while (i < tokens.length) {
      var t = tokens[i];
      while (t.length <= 2 && i + 1 < tokens.length) {
        i++;
        t = '$t${tokens[i]}';
      }
      out.add(t);
      i++;
    }
    return ' ${out.join(' ')} ';
  }

  // ── Fuzzy eşleşme (edit distance ≤1) ──────────────────────────────
  // Kritik niyet kelimeleri için yazım hatası toleransı — varyant listesi
  // tutma yarışına son ("aranyor", "satlik", "siparş"... hepsi yakalanır).
  static bool _editDistanceLe1(String a, String b) {
    final la = a.length, lb = b.length;
    if ((la - lb).abs() > 1) return false;
    if (a == b) return true;
    var ia = 0, ib = 0, edits = 0;
    while (ia < la && ib < lb) {
      if (a[ia] == b[ib]) {
        ia++;
        ib++;
        continue;
      }
      if (++edits > 1) return false;
      if (la == lb) {
        ia++;
        ib++; // substitution
      } else if (la > lb) {
        ia++; // deletion in b
      } else {
        ib++; // insertion in b
      }
    }
    return edits + (la - ia) + (lb - ib) <= 1;
  }

  /// Metindeki herhangi bir token, [signals]'tan birine edit-distance ≤1
  /// uzaklıkta mı? Yalnız ≥6 harfli sinyallerde fuzzy (kısa kelimede
  /// false-positive riski yüksek); kısa sinyaller exact substring kalır.
  static bool _fuzzyHasAny(String norm, List<String> signals) {
    final tokens = norm.trim().split(' ');
    for (final sig in signals) {
      final s = _asciiFold(sig).replaceAll(' ', '');
      if (s.length < 6) {
        if (norm.contains(_asciiFold(sig))) return true;
        continue;
      }
      for (final t in tokens) {
        if (_editDistanceLe1(t, s)) return true;
      }
      if (norm.contains(_asciiFold(sig))) return true;
    }
    return false;
  }

  // Küfür sesli-harf iskeleti — "skeym" gibi sesli düşürülmüş yazımları
  // yakalar. ÇAKIŞMA GUARD'I: kelime gerçekten ağır sesli-düşürmeli olmalı
  // (uzunluk farkı ≤1) — aksi halde "sektör"→'sktr' gibi normal kelimeler
  // yanlış pozitif verir (saha riski; testle kilitli).
  static const Set<String> _profanitySkeletons = {
    'sktr', // siktir → sktr
    'skym', // sikeyim → skeym
    'skrm', // sikerim → skerm
    'yrrk', // yarrak
  };

  static bool _hasProfanitySkeleton(String norm) {
    for (final word in norm.trim().split(' ')) {
      if (word.length < 4) continue;
      final skeleton = word.replaceAll(RegExp('[aeiou]'), '');
      if (skeleton.length >= 4 &&
          word.length - skeleton.length <= 1 &&
          _profanitySkeletons.contains(skeleton)) {
        return true;
      }
    }
    return false;
  }

  static bool _hasWord(String norm, String word) {
    final w = _asciiFold(word);
    return norm.contains(' $w ') || norm.contains(' $w?');
  }

  static bool _hasAny(String norm, List<String> words) =>
      words.any((w) => norm.contains(_asciiFold(w)));

  // ── Sinyal listeleri ──────────────────────────────────────────────
  // Profanity — yalnız tartışmasız token'lar (false-positive riski düşük).
  static const List<String> _profanityWords = [
    'amk', 'aq', 'oç', 'siktir', 'sikeyim', 'sikerim', 'amına', 'amina',
    'orospu', 'piç', 'pic', 'yarrak', 'pezevenk', 'kahpe', 'şerefsiz',
    'ananı', 'anani', 'gavat',
  ];

  static const List<String> _scamPhrases = [
    'kaçak ürün', 'kaçak mal', 'kaçak sigara', 'sahte belge', 'sahte fatura',
    'sahte ruhsat', 'sahte sertifika', 'yasa dışı', 'yasadışı',
    'belgesiz satış', 'faturasız satış',
  ];

  // Satış niyeti (workplace/equipment ortak).
  static const List<String> _saleIntent = [
    'satılık', 'satıyorum', 'satıyoruz', 'satışta', 'sahibinden',
    'acil satış', 'fiyatı uygun', 'devren',
  ];

  // İşyeri/devir isimleri.
  static const List<String> _workplacePhrases = [
    'devren satılık', 'devren kiralık', 'işyeri satılık', 'iş yeri satılık',
    'dükkan devri', 'dükkan satılık', 'fırın devri', 'fırın satılık',
    'işletme devredilecek', 'işletme satılık', 'komple satılık',
    'devredilecektir', 'devirlik',
  ];

  // Ekipman/makine isimleri (yalın "fırın" hariç — o işyeri sinyali).
  static const List<String> _equipmentNouns = [
    'makine', 'makina', 'makinesi', 'makinası', 'mikser', 'kazan', 'raf',
    'tezgah', 'dilimleme', 'paketleme', 'mayalama', 'yoğurma', 'ekipman',
    'soğutucu', 'dolap', 'teşhir', 'arabası', 'kalıp',
  ];

  // İşveren "eleman arıyor" isimleri + niyetleri.
  static const List<String> _hiringNouns = [
    'eleman', 'usta', 'personel', 'işçi', 'çırak', 'tezgahtar', 'kalfa',
    'pastacı', 'hamurkar', 'hamurkâr', 'şoför', 'kurye',
  ];
  // Yazım varyantları artık fuzzy (edit-distance ≤1) ile yakalanır —
  // varyant listesi tutulmaz ("aranyor", "aranıyo", "alnacak"...).
  static const List<String> _hiringIntent = [
    'aranıyor', 'alınacak', 'alınacaktır', 'arıyoruz', 'aramaktayız',
    'işe alım', 'başvuru için',
  ];
  static const List<String> _hiringStrongExtras = [
    'maaş', 'yatılı', 'sigortalı', 'acil eleman', 'dolgun',
  ];

  // İş arayan birey (yumuşak yönlendirme → İş Arıyorum ilanı).
  static const List<String> _jobSeekPhrases = [
    'iş arıyorum', 'is arıyorum', 'iş arıyom', 'iş bakıyorum',
    'çalışmak istiyorum', 'eleman olarak çalışırım',
  ];

  // Ticari reklam/spam niyeti.
  static const List<String> _adStrong = [
    'reklamdır', 'fiyat listesi', 'sipariş için', 'sipariş almak',
    'siparişleriniz',
    // 'toptan sat' prefix'i satış/satıyoruz/sat yazımlarının hepsini kapsar.
    'toptan sat', 'toptan fiyat', 'ürünlerimiz',
    'kampanyamız', 'kampanya', 'indirim', 'stoklarla sınırlı',
    'bayilik verilecektir', 'bayilik veriyoruz', 'bayi alınacak',
    'dm den ulaş', 'dmden ulaş', 'whatsapptan sipariş', 'numaradan sipariş',
  ];

  // Soru / sohbet işaretleri — zayıf sinyalleri sohbete çevirir.
  static const List<String> _discussionMarkers = [
    '?', 'nasıl', 'neden', 'sizce', 'ne yapıyorsunuz', 'ne yapıyorsun',
    'öneri', 'tavsiye', 'dikkat', 'deneyim', 'yaşayan var mı', 'bilen var',
    'zor', 'bulamıyor', 'bulamıyoruz', 'sorun', 'problem', 'arıza', 'bozuldu',
  ];

  /// İki kelime listesinin aynı metinde yakın geçmesi (kaba yakınlık V1:
  /// aynı metinde ikisi de var; kelime mesafesi P2). Niyet tarafı fuzzy —
  /// yazım hatası niyeti gizleyemez.
  static bool _pairs(String norm, List<String> nouns, List<String> intents) {
    return _hasAny(norm, nouns) && _fuzzyHasAny(norm, intents);
  }

  // ── Ana sınıflandırma — feed post ─────────────────────────────────
  static FeedBoundaryResult classifyPost(String text) {
    final raw = text.trim();
    // Boş text (yalnız medya) → serbest; medya tek başına engellenmez.
    if (raw.isEmpty) return FeedBoundaryResult.ok;
    final norm = _normalize(raw);
    final glued = _glued(norm);
    final discussion = _hasAny(norm, _discussionMarkers);

    // 1) Güvenlik: profanity / scam — her zaman önce, tartışma işareti
    // engeli kaldırmaz. Glued form ("s-keym"→"skeym") + sesli-harf iskeleti
    // obfuscation'ı da yakalar.
    if (_profanityWords
            .any((w) => _hasWord(norm, w) || _hasWord(glued, w)) ||
        _hasProfanitySkeleton(norm) ||
        _hasProfanitySkeleton(glued)) {
      return const FeedBoundaryResult(
        allowed: false,
        category: FeedBoundaryCategory.profanity,
        confidence: FeedBoundaryConfidence.high,
        destination: FeedBoundaryDestination.safetyRewrite,
        reason: 'profanity-token',
      );
    }
    if (_hasAny(norm, _scamPhrases)) {
      return const FeedBoundaryResult(
        allowed: false,
        category: FeedBoundaryCategory.scamOrIllegal,
        confidence: FeedBoundaryConfidence.high,
        destination: FeedBoundaryDestination.safetyRewrite,
        reason: 'scam-phrase',
      );
    }

    // 2) İşyeri satış/devir — "fırın satılık" dahil (yalın fırın = işyeri).
    // Soru/tartışma bağlamı ("devren fırın bakıyorum, neye dikkat?") alıcı
    // sorusudur → izinli.
    if (!discussion &&
        (_hasAny(norm, _workplacePhrases) ||
            (_hasWord(norm, 'fırın') &&
                _fuzzyHasAny(norm, _saleIntent) &&
                !_hasAny(norm, _equipmentNouns)))) {
      return const FeedBoundaryResult(
        allowed: false,
        category: FeedBoundaryCategory.workplaceSale,
        confidence: FeedBoundaryConfidence.high,
        destination: FeedBoundaryDestination.workplaceListings,
        reason: 'workplace-sale',
      );
    }

    // 3) Ekipman/makine satışı — ekipman ismi + satış niyeti birlikte.
    // Soru bağlamı ("satılık mikser arıyorum, öneri?") alıcıdır → izinli.
    if (!discussion && _pairs(norm, _equipmentNouns, _saleIntent)) {
      return const FeedBoundaryResult(
        allowed: false,
        category: FeedBoundaryCategory.equipmentSale,
        confidence: FeedBoundaryConfidence.high,
        destination: FeedBoundaryDestination.equipmentListings,
        reason: 'equipment-sale',
      );
    }

    // 4) İş arayan birey — İŞVEREN kontrolünden ÖNCE: "iş arıyorum"
    // (arayan) ile "usta arıyoruz" (işveren) tek harf farkta; fuzzy bu
    // ikisini karıştırmasın diye arayan kalıbı önce ve EXACT kontrol edilir.
    if (_hasAny(norm, _jobSeekPhrases)) {
      return const FeedBoundaryResult(
        allowed: false,
        category: FeedBoundaryCategory.jobSeek,
        confidence: FeedBoundaryConfidence.medium,
        destination: FeedBoundaryDestination.jobSeekListing,
        reason: 'job-seek',
      );
    }

    // 5) İşveren eleman ilanı — isim + niyet birlikte (niyet fuzzy:
    // "aranyor"/"aranıyo" yazımları yakalanır).
    if (_pairs(norm, _hiringNouns, _hiringIntent)) {
      final strong = _hasAny(norm, _hiringStrongExtras) || !discussion;
      if (strong) {
        return const FeedBoundaryResult(
          allowed: false,
          category: FeedBoundaryCategory.jobAd,
          confidence: FeedBoundaryConfidence.high,
          destination: FeedBoundaryDestination.jobListings,
          reason: 'hiring-pattern',
        );
      }
      // İsim+niyet var ama soru/sohbet bağlamı ("usta arıyoruz ama
      // bulamıyoruz, siz nasıl çözüyorsunuz?") → belirsiz sohbet, izin ver.
      return FeedBoundaryResult.ok;
    }

    // 6) Çıplak satış niyeti — domain ismi geçmese bile "satılık X" bir
    // satıştır (saha kanıtı: "satilik araba"). Soru/tartışma bağlamı
    // ("satılık mikser arıyorum, öneri?") alıcı sorusudur → izinli.
    if (_fuzzyHasAny(norm, _saleIntent) && !discussion) {
      return const FeedBoundaryResult(
        allowed: false,
        category: FeedBoundaryCategory.commercialAd,
        confidence: FeedBoundaryConfidence.medium,
        destination: FeedBoundaryDestination.market,
        reason: 'bare-sale-intent',
      );
    }

    // 7) Ticari reklam/spam — güçlü reklam kalıbı tek başına yeterli.
    if (_hasAny(norm, _adStrong)) {
      // "kampanya"/"indirim" sohbet içinde de geçebilir ("indirim yapsam mı?")
      // → soru/tartışma işaretiyle yumuşat; diğer kalıplar (fiyat listesi,
      // sipariş, toptan satış, dm) niyet olarak nettir.
      const weakAdTokens = ['kampanya', 'indirim'];
      final onlyWeak = !_adStrong
          .where((t) => !weakAdTokens.contains(t))
          .any((t) => norm.contains(_asciiFold(t)));
      if (onlyWeak && discussion) return FeedBoundaryResult.ok;
      return FeedBoundaryResult(
        allowed: false,
        category: FeedBoundaryCategory.commercialAd,
        confidence: onlyWeak
            ? FeedBoundaryConfidence.medium
            : FeedBoundaryConfidence.high,
        destination: FeedBoundaryDestination.market,
        reason: 'commercial-ad',
      );
    }

    return FeedBoundaryResult.ok;
  }

  // ── Yorumlar — dar kural (yalnız güvenlik + bariz spam) ───────────
  //
  // Ürün kararı: yorumlarda ticari yönlendirme V1'de YOK (bağlam sohbet);
  // yalnız küfür/scam ve link'li bariz reklam engellenir.
  static FeedBoundaryResult classifyComment(String text) {
    final raw = text.trim();
    if (raw.isEmpty) return FeedBoundaryResult.ok;
    final norm = _normalize(raw);
    final glued = _glued(norm);

    if (_profanityWords
            .any((w) => _hasWord(norm, w) || _hasWord(glued, w)) ||
        _hasProfanitySkeleton(norm) ||
        _hasProfanitySkeleton(glued)) {
      return const FeedBoundaryResult(
        allowed: false,
        category: FeedBoundaryCategory.profanity,
        confidence: FeedBoundaryConfidence.high,
        destination: FeedBoundaryDestination.safetyRewrite,
        reason: 'profanity-token',
      );
    }
    if (_hasAny(norm, _scamPhrases)) {
      return const FeedBoundaryResult(
        allowed: false,
        category: FeedBoundaryCategory.scamOrIllegal,
        confidence: FeedBoundaryConfidence.high,
        destination: FeedBoundaryDestination.safetyRewrite,
        reason: 'scam-phrase',
      );
    }
    // Bariz link spam / sipariş reklamı.
    final hasLink = raw.contains('http://') || raw.contains('https://');
    if (hasLink && _hasAny(norm, _adStrong)) {
      return const FeedBoundaryResult(
        allowed: false,
        category: FeedBoundaryCategory.commercialAd,
        confidence: FeedBoundaryConfidence.high,
        destination: FeedBoundaryDestination.safetyRewrite,
        reason: 'comment-link-spam',
      );
    }
    return FeedBoundaryResult.ok;
  }
}
