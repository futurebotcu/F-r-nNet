// PR #110 devam turu — üç doğrulanmış açığın regresyon testleri.
// Bu dosya ÖNCE mevcut hatalı kodda çalıştırılıp KIRMIZI kanıt alınır,
// düzeltme sonrası YEŞİL olması gerekir.
import {
  checkClaimsAgainstSource,
  discoverArticles,
  extractPage,
  isLikelyArticle,
} from "./lib.ts";

function assert(cond: boolean, msg: string) {
  if (!cond) throw new Error("ASSERT: " + msg);
}
function eq<T>(a: T, b: T, msg: string) {
  if (a !== b) throw new Error(`ASSERT ${msg}: ${a} != ${b}`);
}

// ── HATA 1: iddia denetimi birim/anlam ──────────────────────────────
Deno.test("H1-A: gram↔kg aynı sınıf diye AYNI MİKTAR sayılmaz", () => {
  const src =
    "Üretim notunda hamura 20 gram malzeme eklendiği açıkça belirtilmiştir.";
  const r = checkClaimsAgainstSource(
    [{
      claim: "Hamura 20 kg malzeme eklenmiştir.",
      quote:
        "Üretim notunda hamura 20 gram malzeme eklendiği açıkça belirtilmiştir",
    }],
    src,
    "Hamura 20 kg malzeme eklenmiştir.",
  );
  assert(!r.ok, "20 gram kaynağı 20 kg iddiasını DOĞRULAMAMALI");
});

Deno.test("H1-B: dakika↔saat eşdeğer sayılmaz", () => {
  const src =
    "İşlem kaydında bu aşamanın 20 dakika sürdüğü açıkça belirtilmiştir.";
  const r = checkClaimsAgainstSource(
    [{
      claim: "Bu aşama 20 saat sürmüştür.",
      quote:
        "İşlem kaydında bu aşamanın 20 dakika sürdüğü açıkça belirtilmiştir",
    }],
    src,
    "Bu aşama 20 saat sürmüştür.",
  );
  assert(!r.ok, "20 dakika kaynağı 20 saat iddiasını DOĞRULAMAMALI");
});

Deno.test("H1-C: olumsuzluk yönü korunur (bekletilmemeli ≠ bekletilmeli)",
  () => {
    const src = "Bu örnekte hamur 20°C sıcaklıkta bekletilmemelidir.";
    const r = checkClaimsAgainstSource(
      [{
        claim: "Bu örnekte hamur 20°C sıcaklıkta bekletilmelidir.",
        quote: "Bu örnekte hamur 20°C sıcaklıkta bekletilmemelidir",
      }],
      src,
      "Bu örnekte hamur 20°C sıcaklıkta bekletilmelidir.",
    );
    assert(!r.ok, "zıt yönlü tavsiye DOĞRULANMAMALI");
  });

Deno.test("H1: doğru birim dönüşümü KABUL (0,02 kg quote ↔ 20 gram claim)",
  () => {
    const src = "Her hamur partisine 0.02 kg tuz eklenir ve karıştırılır.";
    const r = checkClaimsAgainstSource(
      [{
        claim: "Partiye 20 gram tuz eklenir.",
        quote: "Her hamur partisine 0.02 kg tuz eklenir ve karıştırılır",
      }],
      src,
      "Partiye 20 gram tuz eklenir.",
    );
    assert(r.ok,
      "eşdeğer miktar (20 g = 0.02 kg) kabul edilmeli: " +
        r.failed.join(","));
  });

Deno.test("H1: yanlış malzeme eşleştirmesi RED (un miktarı mayayı " +
  "doğrulamaz)", () => {
  const src = "Add 20 grams of flour to the starter and mix well.";
  const r = checkClaimsAgainstSource(
    [{
      claim: "Mayaya 20 gram su eklenir.",
      quote: "Add 20 grams of flour to the starter and mix well",
    }],
    src,
    "Mayaya 20 gram su eklenir.",
  );
  assert(!r.ok, "un(flour) kaynağı su/maya iddiasını doğrulamamalı");
});

Deno.test("H1: gerçek EN pasajından doğru TR özet KABUL", () => {
  const src = "For this recipe add 20 grams of yeast to the dough and " +
    "let it rest for 45 minutes before shaping.";
  const r = checkClaimsAgainstSource(
    [{
      claim: "Hamura 20 gram maya eklenir.",
      quote: "add 20 grams of yeast to the dough",
    }, {
      claim: "Hamur 45 dakika dinlendirilir.",
      quote: "let it rest for 45 minutes before shaping",
    }],
    src,
    "Hamura 20 gram maya eklenir ve 45 dakika dinlendirilir.",
  );
  assert(r.ok, "doğru TR özet reddedildi: " + r.failed.join(","));
});

Deno.test("H1: doğru claim yanına gövdede desteksiz teknik iddia RED",
  () => {
    const src = "Add 20 grams of yeast to the dough.";
    const r = checkClaimsAgainstSource(
      [{
        claim: "Hamura 20 gram maya eklenir.",
        quote: "Add 20 grams of yeast to the dough",
      }],
      src,
      // Gövdeye claims'te olmayan desteksiz 250°C eklendi.
      "Hamura 20 gram maya eklenir. Fırın 250°C olmalıdır.",
    );
    assert(!r.ok, "desteksiz 250°C gövde iddiası geçmemeli");
  });

// ── HATA 2: yanlış içerik kanıtları ─────────────────────────────────
function pageOf(title: string, bodyHtml: string, url: string) {
  const html = `<html><head><title>${title}</title></head><body>
    ${bodyHtml}</body></html>`;
  return { html, page: extractPage(html, url), url };
}

Deno.test("H2: iletişim/giriş/çerez/kontakt sayfaları KANIT DEĞİL", () => {
  const cases = [
    pageOf("İletişim", "<p>" + "Adres ve telefon bilgileri. ".repeat(40) +
      "</p><form><input/><input/><input/></form>",
      "https://kosgeb.gov.tr/site/tr/genel/iletisim"),
    pageOf("Giriş", "<p>" + "Oturum açın veya kayıt olun. ".repeat(40) +
      "</p><form><input/><input/></form>",
      "https://dergipark.org.tr/tr/user/notification"),
    pageOf("Çerez Politikası", "<p>" +
      "Bu politika çerezlerin kullanımını açıklar. ".repeat(40) + "</p>",
      "https://iskur.gov.tr/kurumsal/bilgi-sayfalari/" +
        "turkiye-is-kurumu-cerez-politikasi/"),
    pageOf("Kontaktformular", "<p>" + "Bitte fullen Sie das Formular aus. "
      .repeat(40) + "</p><form><input/><input/><input/></form>",
      "https://ireks.com/kontakt/kontaktformular"),
  ];
  for (const c of cases) {
    assert(!isLikelyArticle(c.page, c.html, c.url),
      "kanıt sayılmamalıydı: " + c.url);
  }
  // İkinci sızıntı sınıfı: kurumsal biyografi/tanıtım + DE gizlilik.
  const corp = [
    pageOf("Başkan", "<p>" + "Başkanımızın özgeçmişi ve görevleri. "
      .repeat(40) + "</p>", "https://kosgeb.gov.tr/site/tr/genel/" +
      "liste/6164/baskan"),
    pageOf("Bakan", "<p>" + "Bakanın kariyeri ve görev süresi. "
      .repeat(40) + "</p>", "https://iskur.gov.tr/kurumsal/bakan/"),
    pageOf("Über uns", "<p>" + "Unsere Firmengruppe und Geschichte. "
      .repeat(40) + "</p>", "https://ireks.com/firmengruppe/ueber-uns"),
    pageOf("Datenschutz: Enstitü", "<p>" +
      "Datenschutzerklärung und Rechte. ".repeat(40) + "</p>",
      "https://mri.bund.de/de/datenschutz/"),
  ];
  corp.push(
    pageOf("Genel Müdür Samet Güneş", "<p>" +
      "Genel müdürümüzün özgeçmişi. ".repeat(40) + "</p>",
      "https://iskur.gov.tr/kurumsal/genel-mudur/"),
    pageOf("Tarihçe - KOSGEB", "<p>" +
      "Kurumumuzun kuruluş tarihçesi ve gelişimi. ".repeat(40) + "</p>",
      "https://kosgeb.gov.tr/site/tr/genel/tarihce"),
  );
  for (const c of corp) {
    assert(!isLikelyArticle(c.page, c.html, c.url),
      "kurumsal/biyografi/gizlilik kanıt sayılmamalıydı: " + c.url);
  }
});

Deno.test("H2: gerçek haber/evergreen/üretici teknik dokümanı KABUL", () => {
  const news = pageOf("Buğday rekoltesi açıklandı",
    "<article><p>" +
      "Bu yıl buğday rekoltesi ve un kalitesi üzerine ayrıntılar. "
        .repeat(30) + "</p></article>",
    "https://kaynak.org/haber/bugday-rekoltesi-2026");
  assert(isLikelyArticle(news.page, news.html, news.url), "haber kabul");
  // Akademik sayfa: <article> etiketi YOK ama uzun paragraflar var.
  const paper = pageOf("Effects of fermentation time on dough rheology",
    "<div><p>" +
      "Fermentation temperature and dough rheology were measured. "
        .repeat(40) + "</p></div>",
    "https://uni.edu/papers/dough-rheology");
  assert(isLikelyArticle(paper.page, paper.html, paper.url),
    "article etiketi yok diye akademik sayfa reddedilmemeli");
  const techDoc = pageOf("RONDO katmanlama hattı teknik özellikleri",
    "<main><p>" + "Hat hızı, hamur bandı kalınlık aralığı ve bakım. "
      .repeat(35) + "</p></main>",
    "https://rondo-online.com/docs/katmanlama-teknik");
  assert(isLikelyArticle(techDoc.page, techDoc.html, techDoc.url),
    "üretici TEKNİK dokümanı kabul edilmeli");
});

// ── HATA 3: cursor okunmamış makaleleri atlıyor ─────────────────────
const ART = (i: number) =>
  `<html><head><title>Makale ${i}</title></head><body><article><p>` +
  `Teknik içerik ${i}. `.repeat(60) + `</p></article></body></html>`;

function tenArticleMap(): Record<string, string> {
  const m: Record<string, string> = {
    "https://k.org/sitemap.xml": "<urlset>" +
      Array.from({ length: 10 }, (_, i) =>
        `<url><loc>https://k.org/articles/${i}</loc></url>`).join("") +
      "</urlset>",
  };
  for (let i = 0; i < 10; i++) m[`https://k.org/articles/${i}`] = ART(i);
  return m;
}
const ff = (m: Record<string, string>) => (u: string) =>
  Promise.resolve(m[u] !== undefined ? { status: 200, text: m[u] } : null);

Deno.test("H3: 10 makale / maxArticles=5 → cursor 5'ten devam eder " +
  "(okunmamış 5-7 atlanmaz)", async () => {
  const m = tenArticleMap();
  const r1 = await discoverArticles({
    domain: "k.org",
    startUrls: ["https://k.org/sitemap.xml"],
    cursor: {},
    fetchFn: ff(m),
    robotsTxt: null,
    maxFetch: 12,
    maxArticles: 5,
  });
  eq(r1.articles.length, 5, "ilk tur 5 makale");
  eq(r1.nextCursor.offset, 5,
    "cursor yalnız DENENEN kadar ilerlemeli (8 değil)");
  const r2 = await discoverArticles({
    domain: "k.org",
    startUrls: ["https://k.org/sitemap.xml"],
    cursor: r1.nextCursor,
    fetchFn: ff(m),
    robotsTxt: null,
    maxFetch: 12,
    maxArticles: 5,
  });
  const titles = r2.articles.map((a) => a.title);
  assert(titles.includes("Makale 5") && titles.includes("Makale 6") &&
    titles.includes("Makale 7"), "5-7 sonraki turda OKUNMALI: " + titles);
});

Deno.test("H3: maxArticles=1 → offset 1; fetch bütçesi ortada dolarsa " +
  "kalanlar sonraki tura kalır", async () => {
  const m = tenArticleMap();
  const r = await discoverArticles({
    domain: "k.org",
    startUrls: ["https://k.org/sitemap.xml"],
    cursor: {},
    fetchFn: ff(m),
    robotsTxt: null,
    maxFetch: 12,
    maxArticles: 1,
  });
  eq(r.articles.length, 1, "tek makale");
  eq(r.nextCursor.offset, 1, "offset 1 olmalı");
  // maxFetch=3: sitemap(1) + 2 makale denemesi → offset 2.
  const r2 = await discoverArticles({
    domain: "k.org",
    startUrls: ["https://k.org/sitemap.xml"],
    cursor: { sitemaps: ["https://k.org/sitemap.xml"], si: 0, offset: 0 },
    fetchFn: ff(m),
    robotsTxt: null,
    maxFetch: 3,
    maxArticles: 5,
  });
  eq(r2.nextCursor.offset, 2, "bütçe dolunca yalnız denenenler sayılır");
});

Deno.test("H3: reddedilen sayfa İLERLEME sayılır; alt-sitemap geçişi " +
  "kayıpsız; dupe URL tek makale", async () => {
  const m: Record<string, string> = {
    "https://k.org/sitemap.xml": `<sitemapindex>
      <sitemap><loc>https://k.org/sm-a.xml</loc></sitemap>
      <sitemap><loc>https://k.org/sm-b.xml</loc></sitemap>
      </sitemapindex>`,
    "https://k.org/sm-a.xml": `<urlset>
      <url><loc>https://k.org/kategori</loc></url>
      <url><loc>https://k.org/articles/1</loc></url>
      <url><loc>https://k.org/articles/1</loc></url>
      </urlset>`,
    "https://k.org/sm-b.xml": `<urlset>
      <url><loc>https://k.org/articles/2</loc></url></urlset>`,
    "https://k.org/kategori": "<html><head><title>Arşiv</title></head>" +
      "<body>" + Array.from({ length: 60 }, (_, i) =>
        `<a href="/x${i}">l${i}</a>`).join(" ") + "</body></html>",
    "https://k.org/articles/1": ART(1),
    "https://k.org/articles/2": ART(2),
  };
  let cursor: Record<string, unknown> = {};
  const all: string[] = [];
  for (let i = 0; i < 5; i++) {
    const r = await discoverArticles({
      domain: "k.org",
      startUrls: ["https://k.org/sitemap.xml"],
      cursor,
      fetchFn: ff(m),
      robotsTxt: null,
      maxFetch: 12,
      maxArticles: 5,
    });
    all.push(...r.articles.map((a) => a.title));
    cursor = r.nextCursor as Record<string, unknown>;
    if ((cursor as { done_at?: string }).done_at) break;
  }
  eq(all.filter((t) => t === "Makale 1").length, 1,
    "dupe URL tek makale üretir");
  assert(all.includes("Makale 2"), "alt-sitemap geçişinde kayıp yok");
});

Deno.test("H2: TR windows-1254 charset — başlık doğru çözülür ve tür " +
  "kalıbı kaçmaz", async () => {
  const { decodeBody, detectCharset } = await import("./lib.ts");
  // 'Genel Müdür' windows-1254 baytları (ü=0xFC).
  const bytes = new Uint8Array([
    ...new TextEncoder().encode("<html><head><title>Genel M"),
    0xFC,
    ...new TextEncoder().encode("d"),
    0xFC,
    ...new TextEncoder().encode("r</title></head><body><p>"),
    ...new TextEncoder().encode("ozgecmis ".repeat(60)),
    ...new TextEncoder().encode("</p></body></html>"),
  ]);
  eq(detectCharset("text/html; charset=iso-8859-9", ""), "windows-1254",
    "iso-8859-9 → windows-1254");
  const html = decodeBody(bytes, "text/html; charset=iso-8859-9");
  assert(html.includes("Genel Müdür"), "başlık doğru çözüldü: " + html.slice(0, 60));
  const page = extractPage(html, "https://x.gov.tr/kurumsal/gm");
  assert(!isLikelyArticle(page, html, "https://x.gov.tr/kurumsal/gm"),
    "çözülen 'Genel Müdür' başlığı türe takılmalı");
});

Deno.test("H2: iştirakler/kurum-ana-sayfa başlıkları kanıt değil", () => {
  const c = pageOf("İştiraklerimiz - KOSGEB", "<p>" +
    "Kurum iştiraklerinin listesi ve payları. ".repeat(40) + "</p>",
    "https://kosgeb.gov.tr/site/tr/genel/istirakler");
  assert(!isLikelyArticle(c.page, c.html, c.url), "iştirakler reddi");
});

// ── H4: kapsam seçimi — ilk <article> teaser'ı gerçek gövdeyi gölgeliyor ──
Deno.test("H4a: kısa teaser article + uzun gerçek article → uzun gövde seçilir", () => {
  const long = "Ekşi maya fermantasyonunda sıcaklık kontrolü hamurun gelişimini belirler. ".repeat(60);
  const html = `<html><head><title>Ekşi Maya Rehberi</title></head><body>
    <article><a href="/x">İlgili yazı: bagel</a></article>
    <article><h1>Ekşi Maya Rehberi</h1><p>${long}</p></article></body></html>`;
  const page = extractPage(html, "https://ornek.com/eksi-maya-rehberi/");
  assert(page.text.length > 2000, `gövde kısa kaldı: ${page.text.length}`);
  assert(isLikelyArticle(page, html, "https://ornek.com/eksi-maya-rehberi/"), "makale reddedildi");
});

Deno.test("H4b: yoğun site menüsü makale dışındaysa linkDensity makaleyi reddetmez", () => {
  const nav = Array.from({ length: 300 }, (_, i) => `<a href="/n${i}">x</a>`).join("");
  const body = "Tam buğday unuyla hamur hidrasyonu ve yoğurma süresi üzerine ayrıntılı inceleme. ".repeat(50);
  const html = `<html><head><title>Hamur Hidrasyonu</title></head><body>
    <nav>${nav}</nav><main><h1>Hamur Hidrasyonu</h1><p>${body}</p></main></body></html>`;
  const page = extractPage(html, "https://ornek.com/hamur-hidrasyonu/");
  assert(isLikelyArticle(page, html, "https://ornek.com/hamur-hidrasyonu/"),
    "menü linkleri makaleyi reddettirdi");
});

Deno.test("H4c: kategori/listeleme sayfası hâlâ RED (article'sız çok-link)", () => {
  const links = Array.from({ length: 80 }, (_, i) =>
    `<a href="/tarif${i}">Tarif ${i} ekmek</a>`).join(" ");
  const html = `<html><head><title>Category: Recipes</title></head><body>${links}
    <p>${"Ekmek tarifleri listesi. ".repeat(30)}</p></body></html>`;
  const page = extractPage(html, "https://ornek.com/category/recipes/");
  assert(!isLikelyArticle(page, html, "https://ornek.com/category/recipes/"), "listeleme kabul edildi");
});

Deno.test("H4d: köke işaret eden canonical yok sayılır (makale URL'si korunur)", () => {
  const html = `<html><head><title>Tam Buğday Sandviç Ekmeği</title>
    <link rel="canonical" href="https://ornek.com/"/></head>
    <body><article><p>${"Hamur mayalama ve pişirme adımları. ".repeat(30)}</p></article></body></html>`;
  const p = extractPage(html, "https://ornek.com/ww-subs/");
  assert(p.canonicalUrl === null, "kök canonical yok sayılmalı");
});

Deno.test("H2: Hakkında / Kalite Yönetimi kurumsal sayfaları kanıt değil", () => {
  const a = pageOf("Hakkında - Gıda Hattı", "<p>" +
    "Kuruluşumuz gıda haberciliği yapar. ".repeat(40) + "</p>",
    "https://gidahatti.com/bilgi/kurulus");
  assert(!isLikelyArticle(a.page, a.html, a.url), "hakkında reddi");
  const b = pageOf("Mauri Maya | Global Deneyim", "<p>" +
    "Kalite yönetim sistemimiz un ve maya üretimini kapsar. ".repeat(40) + "</p>",
    "https://mauri.com.tr/tr/kurumsal/KaliteYonetimi");
  assert(!isLikelyArticle(b.page, b.html, b.url), "kalite yönetimi reddi");
});

Deno.test("H2: kurumsal/ yolu ve medya-merkezi/yayın-ilkeleri kanıt değil", () => {
  for (const [title, url] of [
    ["Mauri Maya | Global Deneyim", "https://mauri.com.tr/tr/kurumsal/CevreYonetimi"],
    ["Media Center", "https://americanbakers.org/about/media-center"],
    ["Yayın İlkeleri - Gıda Hattı", "https://gidahatti.com/bilgi/yayin-ilkeleri"],
  ]) {
    const c = pageOf(title, "<p>" +
      "Ekmek ve unlu mamuller sektörü hakkında kurumsal metin. ".repeat(40) + "</p>", url);
    assert(!isLikelyArticle(c.page, c.html, c.url), "kabul edildi: " + url);
  }
});

// ── H5: kart yerleşimi — uzun başlıkta gövde çerçeveyi taşıyor ──
import { buildCardSvg } from "./card.ts";
import { estimateLlmTokens, sanitizeDateContext } from "./lib.ts";

Deno.test("H5: 3 satırlık başlıkta gövde satırları çerçeve/alt-yazı sınırını aşmaz", () => {
  const svg = buildCardSvg({
    kind: "info",
    botName: "FırınNet Akademi",
    title: "SIAL Paris 17-21 Ekim'de: Fırıncı için ne anlama gelir, ne anlama gelmez?",
    body: "Kaynak kaydına göre SIAL Paris, uluslararası bir gıda fuarıdır. ".repeat(8),
  });
  const ys = [...svg.matchAll(/<text x="80" y="(\d+)" font-family="Open Sans" font-size="32"/g)]
    .map((m) => Number(m[1]));
  assert(ys.length > 0, "gövde satırı yok");
  const maxY = Math.max(...ys);
  assert(maxY <= 545, `gövde taşıyor: son taban çizgisi ${maxY} > 545 (alt yazı 589, çerçeve 615)`);
});

Deno.test("H6: token ön-rezervasyon tahmini gerçek kullanımın altında kalamaz", () => {
  // TR metin ~2.5-3.5 karakter/token; 3'e bölüm + tam yanıt üst sınırı ile
  // tahmin >= (gerçek prompt tokenı + gerçek yanıt tokenı) her durumda.
  const est = estimateLlmTokens(9000, 8000);
  assert(est >= 3000 + 8000, `tahmin küçük: ${est}`);
  assert(estimateLlmTokens(0, 500) === 500, "yanıt-üst-sınır tabanı");
});

Deno.test("H7: date_context iç-talimat cümlesi ve parantez notu yayına sızmaz", () => {
  const raw = "Etkinlik tarihi: 17-21 Ekim 2026 (kaynak yayın tarihi 2026-10-17). " +
    "Etkinlik kaynağın yayın tarihinde başlıyor; geçmiş bir olay gibi anlatılmamalıdır.";
  assert(sanitizeDateContext(raw) === "Etkinlik tarihi: 17-21 Ekim 2026",
    "sanitize: " + sanitizeDateContext(raw));
  // Nokta içeren tarih biçimi bozulmaz
  assert(sanitizeDateContext("Tarih: 01.02.2026") === "Tarih: 01.02.2026", "nokta-tarih");
  assert(sanitizeDateContext("") === "", "bos");
});

// ── K1: video platformu KURALI — makale/kanıt olamaz, transkript kazıma yok ──
import { isVideoPlatformUrl } from "./lib.ts";

Deno.test("K1: video platform URL'leri makale sayılmaz (kural: indirme/transkript yok)", () => {
  for (const u of [
    "https://www.youtube.com/watch?v=abc123",
    "https://youtu.be/abc123",
    "https://vimeo.com/12345",
    "https://www.tiktok.com/@x/video/1",
  ]) {
    assert(isVideoPlatformUrl(u), "platform tespit: " + u);
    const c = pageOf("Ekmek yapımı videosu", "<p>" +
      "Hamur yoğurma ve fermantasyon videolu anlatım açıklaması. ".repeat(40) + "</p>", u);
    assert(!isLikelyArticle(c.page, c.html, c.url), "makale sayıldı: " + u);
  }
  assert(!isVideoPlatformUrl("https://ornek.com/video-hakkinda-yazi"), "yanlış pozitif");
});

// ── K2: Tarif denetimi — fırıncı yüzdesi + gösterim + kopya kuralı ──
import { checkBakersRecipe, formatRecipeLines, hasVerbatimOverlap } from "./lib.ts";

const OK_RECIPE = [
  { name: "Un", grams: 1000 },
  { name: "Su", grams: 680 },
  { name: "Tuz", grams: 20 },
  { name: "İnstant maya", grams: 7 },
];

Deno.test("K2a: geçerli ekmek tarifi bot kipinde (strict) GEÇER", () => {
  const r = checkBakersRecipe(OK_RECIPE, { ovenC: 230, minutes: 35, strict: true });
  assert(r.ok, "red: " + r.errors.join(","));
  assert(r.pct["Su"] === 68, "hidrasyon pct");
});

Deno.test("K2b: aralık dışı bot tarifi RED, usta kipinde UYARI", () => {
  const bad = [
    { name: "Un", grams: 1000 },
    { name: "Su", grams: 300 },      // %30 hidrasyon
    { name: "Tuz", grams: 60 },      // %6 tuz
    { name: "İnstant maya", grams: 40 }, // %4
  ];
  const bot = checkBakersRecipe(bad, { ovenC: 400, strict: true });
  assert(!bot.ok && bot.errors.length >= 4, "bot RED bekleniyordu: " + bot.errors.join(","));
  const usta = checkBakersRecipe(bad, { ovenC: 400, strict: false });
  assert(usta.ok && usta.warnings.length >= 4, "usta uyarı bekleniyordu");
});

Deno.test("K2c: girilen yüzde gramla tutarsızsa HER kipte RED", () => {
  const r = checkBakersRecipe(
    [{ name: "Un", grams: 1000 }, { name: "Su", grams: 680, pct: 60 }],
    { strict: false });
  assert(!r.ok && r.errors[0].startsWith("yuzde_tutarsiz"), r.errors.join(","));
});

Deno.test("K2d: un tabanı yoksa RED", () => {
  assert(!checkBakersRecipe([{ name: "Su", grams: 500 }], { strict: true }).ok, "un tabani");
});

Deno.test("K2e: gösterim gramaj + yüzde birlikte", () => {
  const lines = formatRecipeLines(OK_RECIPE);
  assert(lines[0] === "Un 1000 g (%100)", lines[0]);
  assert(lines[1] === "Su 680 g (%68)", lines[1]);
  assert(lines[2] === "Tuz 20 g (%2)", lines[2]);
});

Deno.test("K2f: 12+ kelime birebir dizi = kopya (uyarlama kuralı)", () => {
  const src = "Bu tarifte önce un su ve tuz karıştırılır sonra hamur yirmi dakika " +
    "dinlendirilir ve nazikçe katlanarak fermantasyona bırakılır";
  const copied = "Notlar: bu tarifte önce un su ve tuz karıştırılır sonra hamur " +
    "yirmi dakika dinlendirilir ve nazikçe katlanır.";
  assert(hasVerbatimOverlap(copied, src), "kopya yakalanmadı");
  const own = "Unu suyla otolize bırakın; tuzu sonradan ekleyip kısa aralıklarla " +
    "katlayarak güçlendirin. Oranlar: %68 hidrasyon, %2 tuz.";
  assert(!hasVerbatimOverlap(own, src), "kendi anlatım yanlış pozitif");
});

Deno.test("K2g: 'Tam buğday unu' gibi ek almış un adları taban sayılır", () => {
  const r = checkBakersRecipe([
    { name: "Tam buğday unu", grams: 600 },
    { name: "Un", grams: 400 },
    { name: "Su", grams: 700 },
    { name: "Tuz", grams: 20 },
    { name: "İnstant maya", grams: 7 },
  ], { ovenC: 235, minutes: 40, strict: true });
  assert(r.ok, "red: " + r.errors.join(","));
  assert(r.pct["Su"] === 70, "hidrasyon %70 olmalı: " + r.pct["Su"]);
});

// ── K3: kart güvenli alanı — metin kenarlara yapışmaz, oran 16:9 ──
import { CARD_SAFE } from "./card.ts";

Deno.test("K3: kart 16:9 ve tüm metin satırları güvenli alanda", () => {
  const svg = buildCardSvg({
    kind: "info",
    botName: "FırınNet Akademi",
    title: "Fırına veriş anı: ısı ve buharın ilk on dakikası neden belirleyici",
    body: "Ekmeğin hacmi büyük ölçüde fırındaki ilk dakikalarda kazanılır. ".repeat(10),
  });
  assert(/width="1200" height="675"/.test(svg), "tuval 1200x675 olmalı");
  for (const m of svg.matchAll(/<text x="(\d+)" y="(\d+)"[^>]*font-size="(\d+)"[^>]*>([^<]*)</g)) {
    const x = Number(m[1]), y = Number(m[2]), fs = Number(m[3]), txt = m[4];
    if (x === 80) {
      // Open Sans ortalama ~0.55em/karakter: sağ kenar tahmini
      const right = x + txt.length * fs * 0.55;
      assert(right <= CARD_SAFE.right, `sağ taşma: "${txt}" ~${Math.round(right)}`);
      assert(y <= CARD_SAFE.footer, `alt taşma: y=${y}`);
    }
  }
});

// ── E: Editoryal kalite katmanı (2026-10-01) ─────────────────────────────
import {
  bakeryRelevance,
  countImperatives,
  countWords,
  decideNeedsVisual,
  editorialQuality,
  nextPublishSlot,
  orderForDiversity,
} from "./lib.ts";

// Canlıdaki SIAL yayınının pratik notlar bölümü (baseline: 9 emir kipi).
const SIAL_NOTES = "1) Takvimi erken kapatın: tarih aralığı yoğun dönemlere denk " +
  "gelebilir; fiyatlar için kendi araştırmanızı yapın. 2) Ziyaret amacınızı tek " +
  "cümleyle yazın. 3) Firma listesini sınırlayıp görüşme randevusu isteyin. " +
  "4) Üretim planını fuar öncesi yazılı planlayın. 5) Tek bir test partisiyle " +
  "başlayın. 6) Bütçe kalemlerini kendi tekliflerinizle doldurun.";

Deno.test("E1: emir kipi sayacı SIAL notlarında yüksek, açıklayıcı metinde ~0", () => {
  assert(countImperatives(SIAL_NOTES) >= 6, "SIAL: " + countImperatives(SIAL_NOTES));
  const calm = "Büyük fuarlarda zamanın önemli kısmı plansız dolaşmaya gidebilir. " +
    "Önceden birkaç hedef firma belirlemek, kısa ziyaretlerde zamanı daha " +
    "verimli kullanmayı kolaylaştırabilir. Hamurun unu ve suyu dengelidir.";
  assert(countImperatives(calm) === 0, "sakin metin: " + countImperatives(calm));
});

Deno.test("E2: fırıncılık ilgisi — protein yaz okulu RED, ekmek/un haberi KABUL", () => {
  const protein = "PROTWIN Yaz Okulu TÜBİTAK MAM'da yapıldı. Proteomik, " +
    "metabolomik ve foodomics yöntemleri, kütle spektrometrisi, NMR, yapay " +
    "sindirim modelleri, SHIME simülasyonu ve mikrobiyom analizleri ele " +
    "alındı. Gıda ve alternatif protein araştırmaları değerlendirildi.";
  assert(!bakeryRelevance(protein).ok, "protein yaz okulu geçmemeli");
  const bread = "Değirmenler bu yıl buğday kalitesindeki düşüş nedeniyle un " +
    "spesifikasyonlarını güncelledi; fırınlar ekmek hamurunda su kaldırmanın " +
    "değiştiğini bildiriyor.";
  assert(bakeryRelevance(bread).ok, "ekmek/un haberi geçmeli");
  const safety = "EFSA, akrilamid ve alerjen etiketleme konusunda gıda " +
    "güvenliği rehberini güncelledi; HACCP planlarında kontaminasyon " +
    "riskleri yeniden sınıflandırıldı.";
  assert(bakeryRelevance(safety).ok, "gıda güvenliği alanı tek başına geçer");
  const energy = "Elektrik dağıtım şirketleri tarife yapısını değiştirdi.";
  assert(!bakeryRelevance(energy).ok, "fırınla bağsız enerji haberi geçmez");
});

Deno.test("E3: uzun haber + emir listesi kalite kapısında işaretlenir", () => {
  const longNews = "SIAL Paris 17-21 Ekim'de Paris'te düzenleniyor. ".repeat(40);
  const q = editorialQuality({
    contentType: "news",
    title: "SIAL Paris 17-21 Ekim'de",
    body: longNews,
    editorialNote: "",
    practicalNotes: SIAL_NOTES,
    recentTitles: [],
  });
  assert(q.warnings.some((w) => w.startsWith("too_long")), q.warnings.join(","));
  assert(q.warnings.some((w) => w.startsWith("imperative")), q.warnings.join(","));
  assert(q.warnings.includes("news_has_action_list"), q.warnings.join(","));
  assert(q.score < 70, "skor: " + q.score);
});

Deno.test("E4: çok aşırı uzunluk ve tekrar eden konu BLOKER", () => {
  const huge = "Kelime ".repeat(800);
  const q = editorialQuality({
    contentType: "news", title: "A", body: huge, editorialNote: "",
    practicalNotes: "", recentTitles: [],
  });
  assert(q.blockers.some((b) => b.startsWith("excessive_length")), q.blockers.join(","));
  const dup = editorialQuality({
    contentType: "technical_explainer",
    title: "Hamur sıcaklığını şansa bırakmayın: hedef sıcaklıkla çalışmak",
    body: "Hamur sıcaklığı fermantasyonun hızını belirler. ".repeat(20),
    editorialNote: "", practicalNotes: "",
    recentTitles: ["Hamur sıcaklığını şansa bırakmayın: hedef sıcaklıkla çalışmak"],
  });
  assert(dup.blockers.includes("duplicate_topic"), dup.blockers.join(","));
});

Deno.test("E5: kaynak-meta konuşması ve uzun giriş uyarısı", () => {
  const q = editorialQuality({
    contentType: "research",
    title: "Protein",
    body: ("Projenin ikinci etkinliği uluslararası katılımla merkezde " +
      "gerçekleştirildi ve farklı kariyer aşamalarındaki araştırmacılar, " +
      "öğrenciler ve uzmanlar bir araya geldi. ").repeat(4) +
      "\n\nKaynak metin bu bulgunun fırıncılığa uygulandığına dair veri içermiyor.",
    editorialNote: "", practicalNotes: "", recentTitles: [],
  });
  assert(q.warnings.includes("long_lead"), q.warnings.join(","));
  assert(q.warnings.includes("source_meta_talk"), q.warnings.join(","));
});

Deno.test("E6: görsel opsiyonel — haber/araştırma/kısa not görselsiz", () => {
  assert(decideNeedsVisual("news", true) === false, "news");
  assert(decideNeedsVisual("research", true) === false, "research");
  assert(decideNeedsVisual("quick_note", true) === false, "quick_note");
  assert(decideNeedsVisual("technical_explainer", true) === true, "tech+evet");
  assert(decideNeedsVisual("technical_explainer", false) === false, "tech+hayır");
});

Deno.test("E7: yayın penceresi 08:00-21:30 İstanbul", () => {
  // 03:00 İst = 00:00Z → aynı gün 08:00 İst = 05:00Z
  const at3 = Date.parse("2026-10-01T00:00:00Z");
  assert(new Date(nextPublishSlot(at3)).toISOString() === "2026-10-01T05:00:00.000Z",
    new Date(nextPublishSlot(at3)).toISOString());
  // 10:00 İst = 07:00Z → olduğu gibi
  const at10 = Date.parse("2026-10-01T07:00:00Z");
  assert(nextPublishSlot(at10) === at10, "gündüz değişmez");
  // 21:45 İst = 18:45Z → ertesi gün 08:00 İst
  const at2145 = Date.parse("2026-10-01T18:45:00Z");
  assert(new Date(nextPublishSlot(at2145)).toISOString() === "2026-10-02T05:00:00.000Z",
    new Date(nextPublishSlot(at2145)).toISOString());
  // 08:00 tam sınır yayınlanabilir
  const at8 = Date.parse("2026-10-01T05:00:00Z");
  assert(nextPublishSlot(at8) === at8, "08:00 açık");
});

Deno.test("E8: çeşitlilik sırası — aynı persona/aynı akademik tür art arda gelmez", () => {
  const out = orderForDiversity(
    [
      { id: "a", bot_key: "bilim_arge", content_type: "research" },
      { id: "b", bot_key: "bilim_arge", content_type: "research" },
      { id: "c", bot_key: "isletme", content_type: "business" },
      { id: "d", bot_key: "ekmek_fermantasyon", content_type: "technical_explainer" },
    ],
    { bot_key: "bilim_arge", content_type: "research" },
  );
  assert(out[0].bot_key !== "bilim_arge", "ilk sıra son yayınla aynı persona olmamalı");
  for (let i = 1; i < out.length; i++) {
    const same = out[i].bot_key === out[i - 1].bot_key ||
      (out[i].content_type === "research" && out[i - 1].content_type === "research");
    if (same) {
      // ancak alternatif kalmadıysa izinli
      const rest = out.slice(i);
      assert(rest.every((r) => r.bot_key === out[i - 1].bot_key || r.content_type === "research"),
        "alternatif varken art arda: " + out.map((o) => o.id).join(""));
    }
  }
});

Deno.test("E9: kelime sayacı", () => {
  assert(countWords("  Un 1000 g,  su\n620 g. ") === 6, String(countWords("  Un 1000 g,  su\n620 g. ")));
});

// ── E10-E12: taslak şeması (content_type / editorial_note / visual) ──
import { validateDraftOutput as vdo } from "./lib.ts";

const baseDraft = {
  kind: "news",
  topic: "fuar",
  title: "SIAL Paris 17-21 Ekim'de",
  body: "SIAL Paris 17-21 Ekim tarihlerinde Paris'te düzenleniyor. ".repeat(3),
  practical_notes: "1) Takvimi kapatın. 2) Firma listesi yazın. 3) Randevu isteyin.",
  tags: [],
  claims: [],
  date_context: "",
  image_brief: "",
  uncertainties: "",
  publishable: true,
};

Deno.test("E10: news türünde pratik not listesi deterministik olarak atılır", () => {
  const r = vdo(JSON.stringify({ ...baseDraft, content_type: "news",
    visual_needed: true }), new Set(["x"]));
  assert(r.ok, "geçmeli");
  if (r.ok) {
    assert(r.draft.practical_notes === "", "news notları boş olmalı");
    assert(r.draft.content_type === "news", "tür");
  }
});

Deno.test("E11: editorial_note içinde URL = uydurma link RED", () => {
  const r = vdo(JSON.stringify({ ...baseDraft, content_type: "business",
    editorial_note: "Ayrıntı için https://ornek.com/fuar sayfasına bakılabilir." }),
    new Set(["x"]));
  assert(!r.ok && r.reason === "fabricated_url", JSON.stringify(r));
});

Deno.test("E12: eski şema (content_type yok) kind'den türetilir; geçersiz tür RED", () => {
  const legacy = vdo(JSON.stringify({ ...baseDraft, kind: "evergreen" }), new Set(["x"]));
  assert(legacy.ok && legacy.draft.content_type === "technical_explainer",
    JSON.stringify(legacy));
  const bad = vdo(JSON.stringify({ ...baseDraft, content_type: "blog" }), new Set(["x"]));
  assert(!bad.ok && bad.reason === "bad_content_type", JSON.stringify(bad));
});
