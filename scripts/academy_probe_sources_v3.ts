// deno run --allow-net --allow-read --allow-write --allow-env \
//   scripts/academy_probe_sources_v3.ts
//
// Kaynak adaylarını WORKER İLE AYNI ÇIKARIM KODUYLA (lib.ts) salt-okunur
// doğrular: RSS varsa feed→makale; yoksa discoverArticles (sitemap index/
// urlset/HTML) — robots + SSRF + makale-kalite (isLikelyArticle) aynı.
// Rapor: docs/academy/source_verification.json (makinece okunabilir).
import {
  discoverArticles,
  extractPage,
  extractPublishedAt,
  isAllowedUrl,
  isLikelyArticle,
  parseFeed,
  robotsAllows,
} from "../supabase/functions/academy-worker/lib.ts";

const UA =
  "FirinNetAcademyBot/1.1 (+https://firinnet.app; kaynak-dogrulama)";
const TIMEOUT = 15000;

async function get(
  url: string,
): Promise<{ status: number; text: string } | null> {
  const ctl = new AbortController();
  const t = setTimeout(() => ctl.abort(), TIMEOUT);
  try {
    const r = await fetch(url, {
      signal: ctl.signal,
      headers: { "User-Agent": UA },
      redirect: "follow",
    });
    const text = (await r.text()).slice(0, 1_500_000);
    return { status: r.status, text };
  } catch (_) {
    return null;
  } finally {
    clearTimeout(t);
  }
}

const data = JSON.parse(
  await Deno.readTextFile("docs/academy/sources_candidates.json"),
);
const results: Record<string, unknown>[] = [];

for (const s of data.sources) {
  console.log("probe:", s.slug);
  const entry: Record<string, unknown> = {
    slug: s.slug,
    name: s.name,
    domain: s.domain,
    country: s.country,
    lang: s.lang,
    type: s.type,
    commercial: s.commercial,
    publisher_group: s.publisher_group ?? null,
    topics: s.topics,
    probed_at: new Date().toISOString(),
  };
  // robots (worker ile aynı uygulanır)
  const robots = await get(`https://${s.domain}/robots.txt`);
  const robotsTxt = robots && robots.status === 200 ? robots.text : null;
  const allow = (u: string) => {
    if (!isAllowedUrl(u, s.domain)) return false;
    if (!robotsTxt) return true;
    try {
      return robotsAllows(robotsTxt, new URL(u).pathname);
    } catch (_) {
      return false;
    }
  };

  let proof: Record<string, unknown> | null = null;
  let method = "";
  let feedSeen = false;

  // 1) RSS/Atom yolu
  for (const u of s.probe as string[]) {
    if (proof) break;
    if (!allow(u)) continue;
    const r = await get(u);
    if (!r || r.status !== 200 || !r.text) continue;
    if (!/<(rss|feed)[\s>]/i.test(r.text)) continue;
    feedSeen = true;
    for (const it of parseFeed(r.text).slice(0, 3)) {
      const link = new URL(it.link, u).toString();
      if (!allow(link)) continue;
      const art = await get(link);
      if (!art || art.status !== 200) continue;
      const page = extractPage(art.text, link);
      if (!isLikelyArticle(page, art.text)) continue;
      proof = {
        url: page.canonicalUrl ?? link,
        title: page.title.slice(0, 200),
        text_len: page.text.length,
        published_at: it.publishedAt ?? extractPublishedAt(art.text),
        method: "rss_item->extractPage",
      };
      break;
    }
  }
  // 2) RSS yoksa/kanıt çıkmadıysa: worker keşif çekirdeği (sitemap/HTML).
  if (!proof) {
    let cursor: Record<string, unknown> = {};
    for (let round = 0; round < 3 && !proof; round++) {
      const r = await discoverArticles({
        domain: s.domain,
        startUrls: [
          ...(s.probe as string[]),
          `https://${s.domain}/sitemap.xml`,
          `https://${s.domain}/`,
        ],
        cursor,
        fetchFn: get,
        robotsTxt,
        maxFetch: 10,
        maxArticles: 1,
      });
      method = r.note;
      cursor = r.nextCursor as Record<string, unknown>;
      if (r.articles.length > 0) {
        const a = r.articles[0];
        proof = {
          url: a.url,
          title: a.title.slice(0, 200),
          text_len: a.text.length,
          published_at: a.publishedAt,
          method: "discover:" + r.note,
        };
      }
      if ((r.nextCursor as { done_at?: string }).done_at) break;
    }
  }

  entry.content_proof = proof;
  entry.verdict = proof
    ? "content_proved"
    : (feedSeen ? "reachable_feed" : "unproved");
  entry.verdict_reason = proof
    ? "gerçek makale çıkarımı worker koduyla doğrulandı"
    : (feedSeen
      ? "feed erişildi; makale kanıtı çıkarılamadı"
      : "feed/sitemap/HTML üzerinden makale kanıtı çıkarılamadı" +
        (method ? ` (${method})` : ""));
  results.push(entry);
}

const proved = results.filter((r) => r.verdict === "content_proved");
const perTopic: Record<string, number> = {};
for (const r of proved) {
  for (const t of r.topics as string[]) perTopic[t] = (perTopic[t] ?? 0) + 1;
}
const report = {
  summary: {
    generated_at: new Date().toISOString(),
    method_note:
      "Doğrulama worker ile AYNI çıkarım kodunu kullanır (lib.ts). " +
      "content_proved = gerçek makale (başlık+ana metin+robots+SSRF) " +
      "kanıtı; lisans/kullanım koşulu onayı DEĞİLDİR.",
    candidates_total: results.length,
    content_proved: proved.length,
    reachable_feed_unproved:
      results.filter((r) => r.verdict === "reachable_feed").length,
    unproved: results.filter((r) => r.verdict === "unproved").length,
    proved_per_topic: perTopic,
  },
  sources: results,
};
await Deno.writeTextFile(
  "docs/academy/source_verification.json",
  JSON.stringify(report, null, 1),
);
console.log("\nSUMMARY:", JSON.stringify(report.summary, null, 1));
