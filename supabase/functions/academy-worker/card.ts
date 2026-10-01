// Deterministik bilgi/mizah kartı — ek API anahtarı GEREKTİRMEZ.
// SVG şablon (FırınNet sarı-beyaz kimliği) + gömülü Open Sans (TR karakter)
// + gömülü resvg-wasm ile PNG raster üretir. Çalışma anında font/wasm
// İNDİRMEZ (base64 modüller deploy paketindedir).

import { initWasm, Resvg } from "npm:@resvg/resvg-wasm@2.6.2";
import { B64 as FONT_REGULAR_B64 } from "./assets_OpenSans_Regular.ts";
import { B64 as FONT_BOLD_B64 } from "./assets_OpenSans_Bold.ts";
import { B64 as RESVG_WASM_B64 } from "./assets_resvg_wasm.ts";

function b64ToBytes(b64: string): Uint8Array {
  const bin = atob(b64);
  const out = new Uint8Array(bin.length);
  for (let i = 0; i < bin.length; i++) out[i] = bin.charCodeAt(i);
  return out;
}

let wasmReady: Promise<void> | null = null;
function ensureWasm(): Promise<void> {
  wasmReady ??= initWasm(b64ToBytes(RESVG_WASM_B64)).catch((e) => {
    // "already initialized" ikinci init'te normaldir.
    if (!String(e).includes("Already initialized")) throw e;
  });
  return wasmReady;
}

// Feed-safe tuval: 16:9 (1200x675). Flutter FeedPostImage kartı bu GERÇEK
// oranda ve BoxFit.contain ile çizer (kırpma yok). Kritik öğeler aşağıdaki
// güvenli alanın içinde kalır; kenarlara yapışan metin yoktur.
const W = 1200;
const H = 675;
export const CARD_SAFE = {
  left: 80, // logo/metin sol kenarı
  right: W - 80, // en uzun satırın sağ sınırı
  titleTop: 160, // başlık ilk taban çizgisinin üstü (logo/isim bloğu altı)
  bodyBottom: 545, // gövde son taban çizgisi
  footer: H - 86, // alt marka satırı
} as const;
const INK = "#1F1B0E"; // brandInk yakını (koyu)
const LEMON = "#F6C90E"; // marka sarısı
const LEMON_PALE = "#FFF8E1";

function esc(s: string): string {
  return s.replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;")
    .replace(/"/g, "&quot;");
}

/** Kaba genişlik tahmini ile kelime sarma (Open Sans ~0.52em/karakter). */
export function wrapText(
  text: string,
  maxChars: number,
  maxLines: number,
): string[] {
  const words = text.replace(/\s+/g, " ").trim().split(" ");
  const lines: string[] = [];
  let cur = "";
  for (const w of words) {
    const cand = cur ? cur + " " + w : w;
    if (cand.length <= maxChars) {
      cur = cand;
    } else {
      if (cur) lines.push(cur);
      cur = w.length > maxChars ? w.slice(0, maxChars - 1) + "…" : w;
      if (lines.length === maxLines - 1) break;
    }
  }
  if (cur && lines.length < maxLines) lines.push(cur);
  if (lines.length === maxLines &&
      words.join(" ").length > lines.join(" ").length) {
    lines[maxLines - 1] = lines[maxLines - 1].replace(/…?$/, "…");
  }
  return lines;
}

export interface CardSpec {
  kind: "info" | "humor";
  botName: string;
  title: string;
  body: string;
}

export function buildCardSvg(spec: CardSpec): string {
  const badge = spec.kind === "humor" ? "MİZAH • AI" : "AKADEMİ • AI";
  const titleLines = wrapText(spec.title, 34, 3);
  const titleY0 = 210;
  const titleLH = 62;
  const bodyY0 = titleY0 + titleLines.length * titleLH + 36;
  const bodyLH = 46;
  // Gövde satır bütçesi KALAN alandan hesaplanır: uzun (3 satırlık) başlık
  // gövdeyi aşağı iter; sabit 6 satır çerçeveyi ve alt yazıyı (y=589) taşar.
  const bodyMaxY = CARD_SAFE.bodyBottom;
  const bodyMaxLines = Math.max(
    1,
    Math.floor((bodyMaxY - bodyY0) / bodyLH) + 1,
  );
  const bodyLines = wrapText(spec.body, 52, Math.min(6, bodyMaxLines));
  const title = titleLines.map((l, i) =>
    `<text x="80" y="${titleY0 + i * titleLH}" font-family="Open Sans" ` +
    `font-weight="700" font-size="48" fill="${INK}">${esc(l)}</text>`
  ).join("");
  const body = bodyLines.map((l, i) =>
    `<text x="80" y="${bodyY0 + i * bodyLH}" font-family="Open Sans" ` +
    `font-size="32" fill="#3D3524">${esc(l)}</text>`
  ).join("");
  return `<svg xmlns="http://www.w3.org/2000/svg" width="${W}" height="${H}">
  <rect width="${W}" height="${H}" fill="#FFFFFF"/>
  <rect width="${W}" height="18" fill="${LEMON}"/>
  <rect y="${H - 18}" width="${W}" height="18" fill="${LEMON}"/>
  <rect x="60" y="60" width="${W - 120}" height="${H - 120}" rx="28"
    fill="${LEMON_PALE}" stroke="${LEMON}" stroke-width="3"/>
  <circle cx="118" cy="126" r="26" fill="${LEMON}"/>
  <text x="104" y="138" font-family="Open Sans" font-weight="700"
    font-size="30" fill="${INK}">F</text>
  <text x="160" y="120" font-family="Open Sans" font-weight="700"
    font-size="30" fill="${INK}">${esc(spec.botName)}</text>
  <text x="160" y="152" font-family="Open Sans" font-size="22"
    fill="#6B6046">${badge}</text>
  ${title}
  ${body}
  <text x="80" y="${H - 86}" font-family="Open Sans" font-size="22"
    fill="#6B6046">FırınNet • fırıncının dijital ustası</text>
</svg>`;
}

/** SVG → PNG raster (Flutter Image.network'ün gösterebildiği format). */
export async function renderCardPng(spec: CardSpec): Promise<Uint8Array> {
  await ensureWasm();
  const svg = buildCardSvg(spec);
  const resvg = new Resvg(svg, {
    fitTo: { mode: "width", value: W },
    font: {
      fontBuffers: [
        b64ToBytes(FONT_REGULAR_B64),
        b64ToBytes(FONT_BOLD_B64),
      ],
      defaultFontFamily: "Open Sans",
      loadSystemFonts: false,
    },
    background: "#FFFFFF",
  });
  const png = resvg.render().asPng();
  return png;
}
