// deno test supabase/functions/academy-worker/lib_quote_test.ts
// Alıntı guard'ı (2026-10-13): DOĞRUDAN ALINTI kaynakta birebir (noktalama/
// boşluk/Unicode toleransı) bulunmalı; yabancı kaynaktan Türkçe PARAPHRASE
// tırnak içine alınmaz, atıfla verilir; kaynakta olmayan sayı/iddia yine RED.
import {
  checkClaimsAgainstSource,
  isLowValueCandidate,
  normQuote,
  orderForDiversity,
  unquoteTranslated,
} from "./lib.ts";

function assert(cond: unknown, msg: string): asserts cond {
  if (!cond) throw new Error("ASSERT: " + msg);
}

const EN_SRC =
  "Despite the use of foreign material removal devices in food processing, " +
  "foreign material is the third most common cause of recalls. " +
  "Focus on sanitation and maintenance as key contributors to management " +
  "of foreign material risks in your plant. " +
  "Burning chamber is made of heat resistive (more than 1000 centigrade " +
  "degree) special stainless steel. Max. temperature o C 350 350 350. " +
  "The course took place on 23 September 2026 and covers tasting.";

Deno.test("1) Kaynakta bulunan gerçek doğrudan quote → PASS", () => {
  const r = checkClaimsAgainstSource(
    [{
      claim: "Yabancı madde, geri çağırmaların en yaygın üçüncü nedenidir.",
      quote: "foreign material is the third most common cause of recalls",
    }],
    EN_SRC,
    "Yabancı madde, geri çağırmaların en yaygın üçüncü nedenidir.",
  );
  assert(r.ok, r.reason + " " + r.failed.join("|"));
});

Deno.test("2) Noktalama / boşluk / Unicode farkı → PASS", () => {
  assert(
    normQuote("Focus on “sanitation”—and  maintenance,") ===
      normQuote('focus on "sanitation" - and maintenance'),
    "normQuote eşdeğerlik",
  );
  const r = checkClaimsAgainstSource(
    [{
      claim:
        "Temizlik ve bakım, yabancı madde riskinin yönetiminde kilit katkıdır.",
      quote: "Focus on sanitation and maintenance as key contributors to " +
        "management of foreign material risks in your plant",
    }],
    EN_SRC.replace(
      "sanitation and maintenance",
      "sanitation  and\nmaintenance",
    ),
    "x",
  );
  assert(r.ok, r.reason + " " + r.failed.join("|"));
});

Deno.test("3) Kaynakta olmayan uydurma quote → RED", () => {
  const r = checkClaimsAgainstSource(
    [{
      claim: "Yabancı madde en sık görülen geri çağırma nedenidir.",
      quote:
        "foreign material is the most common cause of all recalls worldwide",
    }],
    EN_SRC,
    "x",
  );
  assert(
    !r.ok && r.failed[0].includes("quote_not_in_source"),
    r.failed.join("|"),
  );
});

Deno.test("4) İngilizce kaynak → Türkçe atıflı paraphrase (sözlükte olmayan kelimeler) → PASS", () => {
  // Bağlam sözlüğünde 'foreign material / recall' yok; quote kaynakta
  // birebir ve iddiada birimli sayı yok → artık 'uncertain' değil.
  const r = checkClaimsAgainstSource(
    [{
      claim:
        "AIB'ye göre ayıklama cihazlarına rağmen yabancı madde, geri çağırmaların en yaygın üçüncü nedeni.",
      quote:
        "Despite the use of foreign material removal devices in food processing, " +
        "foreign material is the third most common cause of recalls",
    }],
    EN_SRC,
    "x",
  );
  assert(r.ok, r.reason + " " + r.failed.join("|"));
});

Deno.test("5) İngilizce kaynaktan Türkçe metin tırnak içindeyse otomatik paraphrase'e döner; gerçek alıntı kalır", () => {
  const body =
    "Kaynağa göre “yabancı madde, geri çağırmaların en yaygın üçüncü nedeni” ve " +
    'bu yüzden temizlik önemli. Üretici "foreign material is the third most ' +
    'common cause of recalls" diyor.';
  const out = unquoteTranslated(body, EN_SRC);
  assert(
    !out.body.includes("“yabancı madde"),
    "çeviri tırnağı kaldırılır: " + out.body,
  );
  assert(
    out.body.includes("yabancı madde, geri çağırmaların"),
    "metin korunur",
  );
  assert(
    out.body.includes(
      '"foreign material is the third most common cause of recalls"',
    ),
    "kaynakta birebir geçen alıntı tırnağıyla kalır",
  );
  assert(out.changed === 1, "bir dönüşüm: " + out.changed);
});

Deno.test("6) Paraphrase kaynak iddiasını değiştirmiş (sayı) → RED", () => {
  const r = checkClaimsAgainstSource(
    [{
      claim: "Yanma odası 1500 santigrat dereceye dayanan çelikten yapılıyor.",
      quote:
        "Burning chamber is made of heat resistive (more than 1000 centigrade " +
        "degree) special stainless steel",
    }],
    EN_SRC,
    "x",
  );
  assert(!r.ok && r.failed[0].includes("quantity"), r.failed.join("|"));
});

Deno.test("6b) Sayı kaynakla uyumlu ama birim yazımı farklı (centigrade / 'o C') → PASS; tarih sayı sayılmaz", () => {
  const r = checkClaimsAgainstSource(
    [
      {
        claim:
          "Yanma odası 1000 santigrat dereceye dayanan çelikten yapılıyor.",
        quote:
          "Burning chamber is made of heat resistive (more than 1000 centigrade " +
          "degree) special stainless steel",
      },
      {
        claim:
          "Fırınların maksimum çalışma sıcaklığı 350 derece olarak veriliyor.",
        quote: "Max. temperature o C 350 350 350",
      },
      {
        claim: "Kurs 23 Eylül 2026'da tadım üzerine düzenlendi.",
        quote: "The course took place on 23 September 2026 and covers tasting",
      },
    ],
    EN_SRC,
    "x",
  );
  assert(r.ok, r.reason + " " + r.failed.join("|"));
});

Deno.test("Ön eleme: pratik/yerel köprüsü olmayan yabancı basın bülteni LLM'den önce elenir", () => {
  assert(
    isLowValueCandidate({
      title: "Group announces new CEO and Q3 revenue",
      lang: "en",
      relevanceScore: 0.3,
    }),
    "basın bülteni elenir",
  );
  assert(
    !isLowValueCandidate({
      title: "How dough temperature changes proofing time",
      lang: "en",
      relevanceScore: 0.3,
    }),
    "pratik yazı elenmez",
  );
  assert(
    !isLowValueCandidate({
      title: "Özmaya yeni fabrikasını açtı",
      lang: "tr",
      relevanceScore: 0.2,
    }),
    "Türkçe kaynak elenmez",
  );
});

Deno.test("Yayın sırası: aynı bot ve aynı tür arka arkaya gelmez (alternatif varsa)", () => {
  const out = orderForDiversity(
    [
      { id: "a", bot_key: "isletme", content_type: "business" },
      { id: "b", bot_key: "isletme", content_type: "business" },
      { id: "c", bot_key: "un_tahil", content_type: "business" },
      { id: "d", bot_key: "hijyen_kalite", content_type: "hygiene" },
    ],
    null,
  );
  const ids = out.map((c) => c.id).join(",");
  assert(ids === "a,d,c,b" || ids === "a,d,b,c", "sıra: " + ids);
});
