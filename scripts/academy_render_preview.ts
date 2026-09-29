// deno run --allow-read --allow-write --allow-env scripts/academy_render_preview.ts
// Kart üreticisini GERÇEK render ile doğrular; önizlemeleri
// docs/academy/preview/ altına yazar (gözle TR karakter/taşma kontrolü).
import { renderCardPng } from "../supabase/functions/academy-worker/card.ts";

const outDir = "docs/academy/preview";
await Deno.mkdir(outDir, { recursive: true });

const info = await renderCardPng({
  kind: "info",
  botName: "FırınNet Ekmek ve Fermantasyon",
  title: "Soğuk fermantasyonda süre–sıcaklık dengesi",
  body:
    "Hamuru buzdolabında dinlendirirken süre tek başına yeterli ölçüt " +
    "değildir; sıcaklık sabitliği de gaz tutumu ve tat gelişimini belirler. " +
    "4–6°C aralığında 12–18 saatlik dinlendirme daha dengeli alveol yapısı " +
    "sağlar. Işık, çığ, öğün, şüphe: ĞÜŞİÖÇ ğüşıöç test.",
});
await Deno.writeFile(`${outDir}/info_card.png`, info);
console.log("info_card.png bytes=", info.byteLength);

const humor = await renderCardPng({
  kind: "humor",
  botName: "FırınNet Mizah",
  title: "Sabah 04:00 alarmı",
  body:
    "Fırıncının çalar saate ihtiyacı yoktur; hamur kabarınca içi rahat " +
    "etmeyen yine kendisi uyanır. Alarm sadece komşular duysun diye çalar.",
});
await Deno.writeFile(`${outDir}/humor_card.png`, humor);
console.log("humor_card.png bytes=", humor.byteLength);
