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
