// Gera a arte provisória do jogo (PNG, só os 6 tons da paleta). "Arte de programador":
// serve para o jogo funcionar no estilo; desenhem por cima no Pixelorama/Aseprite com o mesmo nome e tamanho.
// Uso: node tools/art/generate.js   (rodar da raiz do repo)
'use strict';
const fs = require('fs'), path = require('path'), zlib = require('zlib');

// Paleta (docs/ESTILO.md): 0 Breu, 1 Carvão, 2 Sombra, 3 Cinza, 4 Névoa, 5 Osso. 255 = transparente.
const PAL = [0x0a, 0x23, 0x47, 0x76, 0xab, 0xe8];
const T = 255;

// ---------- imagem indexada ----------
class Img {
  constructor(w, h, fill = T) { this.w = w; this.h = h; this.px = new Uint8Array(w * h).fill(fill); }
  set(x, y, v) { x = Math.round(x); y = Math.round(y); if (x >= 0 && y >= 0 && x < this.w && y < this.h) this.px[y * this.w + x] = v; }
  get(x, y) { if (x < 0 || y < 0 || x >= this.w || y >= this.h) return T; return this.px[y * this.w + x]; }
  rect(x, y, w, h, v) { for (let j = 0; j < h; j++) for (let i = 0; i < w; i++) this.set(x + i, y + j, v); }
  frame(x, y, w, h, v) { this.rect(x, y, w, 1, v); this.rect(x, y + h - 1, w, 1, v); this.rect(x, y, 1, h, v); this.rect(x + w - 1, y, 1, h, v); }
  line(x0, y0, x1, y1, v, th = 1) {
    x0 = Math.round(x0); y0 = Math.round(y0); x1 = Math.round(x1); y1 = Math.round(y1);
    const dx = Math.abs(x1 - x0), dy = -Math.abs(y1 - y0), sx = x0 < x1 ? 1 : -1, sy = y0 < y1 ? 1 : -1;
    let err = dx + dy;
    for (;;) {
      this.rect(x0 - ((th - 1) >> 1), y0 - ((th - 1) >> 1), th, th, v);
      if (x0 === x1 && y0 === y1) break;
      const e2 = 2 * err;
      if (e2 >= dy) { err += dy; x0 += sx; }
      if (e2 <= dx) { err += dx; y0 += sy; }
    }
  }
  disc(cx, cy, r, v) { for (let y = -r; y <= r; y++) for (let x = -r; x <= r; x++) if (x * x + y * y <= r * r + r * 0.6) this.set(cx + x, cy + y, v); }
  // Mistura dois tons com pontos (dither Bayer): t = 0 só "a", 1 só "b"
  dither(x, y, w, h, a, b, t) { for (let j = 0; j < h; j++) for (let i = 0; i < w; i++) this.set(x + i, y + j, bayer(x + i, y + j) < t ? b : a); }
  blit(src, ox, oy) { for (let y = 0; y < src.h; y++) for (let x = 0; x < src.w; x++) { const v = src.px[y * src.w + x]; if (v !== T) this.set(ox + x, oy + y, v); } }
  map(rows, ox, oy) { rows.forEach((r, y) => [...r].forEach((c, x) => { if (c !== '.') this.set(ox + x, oy + y, +c); })); }
}
const BAYER = [0, 8, 2, 10, 12, 4, 14, 6, 3, 11, 1, 9, 15, 7, 13, 5].map(v => (v + 0.5) / 16);
const bayer = (x, y) => BAYER[((y & 3) << 2) | (x & 3)];
function rng(seed) { return () => { seed |= 0; seed = (seed + 0x6D2B79F5) | 0; let t = Math.imul(seed ^ (seed >>> 15), 1 | seed); t = (t + Math.imul(t ^ (t >>> 7), 61 | t)) ^ t; return ((t ^ (t >>> 14)) >>> 0) / 4294967296; }; }

// ---------- PNG ----------
const CRC = []; for (let n = 0; n < 256; n++) { let c = n; for (let k = 0; k < 8; k++) c = c & 1 ? 0xedb88320 ^ (c >>> 1) : c >>> 1; CRC[n] = c >>> 0; }
const crc = b => { let c = 0xffffffff; for (const x of b) c = CRC[(c ^ x) & 0xff] ^ (c >>> 8); return (c ^ 0xffffffff) >>> 0; };
function chunk(t, d) { const l = Buffer.alloc(4); l.writeUInt32BE(d.length); const td = Buffer.concat([Buffer.from(t), d]); const c = Buffer.alloc(4); c.writeUInt32BE(crc(td)); return Buffer.concat([l, td, c]); }
function save(img, rel) {
  const raw = Buffer.alloc((img.w * 4 + 1) * img.h);
  for (let y = 0; y < img.h; y++) for (let x = 0; x < img.w; x++) {
    const v = img.px[y * img.w + x], o = y * (img.w * 4 + 1) + 1 + x * 4;
    if (v === T) continue;
    raw[o] = raw[o + 1] = raw[o + 2] = PAL[v]; raw[o + 3] = 255;
  }
  const ihdr = Buffer.alloc(13); ihdr.writeUInt32BE(img.w, 0); ihdr.writeUInt32BE(img.h, 4); ihdr[8] = 8; ihdr[9] = 6;
  const file = path.join(process.cwd(), rel);
  fs.mkdirSync(path.dirname(file), { recursive: true });
  fs.writeFileSync(file, Buffer.concat([Buffer.from([137, 80, 78, 71, 13, 10, 26, 10]), chunk('IHDR', ihdr), chunk('IDAT', zlib.deflateSync(raw)), chunk('IEND', Buffer.alloc(0))]));
  console.log('  ' + rel + ' (' + img.w + 'x' + img.h + ')');
}

// ---------- árvore seca recursiva ----------
function tree(img, r, x, ground, h, th, v) {
  img.line(x, ground, x, ground - h, v, th);
  img.line(x - th, ground, x - th - 2, ground + 1, v, 1); img.line(x + th, ground, x + th + 2, ground + 1, v, 1);
  function branch(bx, by, a, len, depth, bt) {
    if (depth === 0 || len < 3) return;
    const ex = bx + Math.cos(a) * len, ey = by + Math.sin(a) * len;
    img.line(bx, by, ex, ey, v, bt);
    branch(ex, ey, a - 0.35 - r() * 0.35, len * 0.68, depth - 1, Math.max(1, bt - 1));
    if (r() < 0.8) branch(ex, ey, a + 0.3 + r() * 0.35, len * 0.62, depth - 1, Math.max(1, bt - 1));
  }
  const n = 3 + Math.floor(r() * 3);
  for (let i = 0; i < n; i++) branch(x, ground - h * (0.4 + r() * 0.55), -Math.PI / 2 + (r() < 0.5 ? -1 : 1) * (0.45 + r() * 0.75), h * (0.2 + r() * 0.2), 4, Math.max(1, th - 1));
}

// ---------- PERSONAGEM 20x32 (de lado, olhando para a direita) ----------
const HEAD = [
  '....................',
  '......00000.........',
  '.....0111110........',
  '....011111110.......',
  '....0111111140......',
  '....01111114440.....',
  '....01111144040.....',
  '....01111144440.....',
  '.....0111144440.....',
  '.....011144440......',
  '......0114440.......',
  '.......00440........',
];
const HEAD_BLINK = HEAD.slice(); HEAD_BLINK[6] = '....01111144440.....';
const BODY = [
  '......0222220.......',
  '.....022222220......',
  '....02222222220.....',
  '....02222200000.....',
  '....0222220333300...',
  '....0222220355530...',
  '....0222220333300...',
  '....02222220000.....',
  '....022222222220....',
  '....022222222220....',
  '....022222222220....',
  '....022322222220....',
  '....022222222220....',
  '.....0222222220.....',
  '.....0000000000.....',
];
const LEGS_STAND = ['......011..011......', '......011..011......', '......011..011......', '......0110.0110.....', '......00000.00000...'];
const LEGS_A = ['.....011....011.....', '....011......011....', '....011......011....', '...0110......0110...', '...0000......00000..'];
const LEGS_C = ['......011.011.......', '.....011...011......', '.....011....011.....', '....0110....0110....', '....0000....00000...'];
const PHOTO_HEAD = HEAD.slice();
PHOTO_HEAD[5] = '....011111140000....';
PHOTO_HEAD[6] = '....011111140333300.';
PHOTO_HEAD[7] = '....011111140355530.';
PHOTO_HEAD[8] = '....011111140333300.';
PHOTO_HEAD[9] = '.....01114440000....';
const PHOTO_BODY = BODY.slice();
for (let i = 3; i <= 7; i++) PHOTO_BODY[i] = '....02222222220.....';
PHOTO_BODY[2] = '....022222222200....';

function playerFrame(head, body, legs) { const f = new Img(20, 32); f.map(head, 0, 0); f.map(body, 0, 12); f.map(legs, 0, 27); return f; }
function playerSheet() {
  const frames = [
    playerFrame(HEAD, BODY, LEGS_STAND),       // 0 parado
    playerFrame(HEAD_BLINK, BODY, LEGS_STAND), // 1 piscando
    playerFrame(HEAD, BODY, LEGS_A),           // 2-5 andando
    playerFrame(HEAD, BODY, LEGS_STAND),
    playerFrame(HEAD, BODY, LEGS_C),
    playerFrame(HEAD, BODY, LEGS_STAND),
    playerFrame(PHOTO_HEAD, PHOTO_BODY, LEGS_STAND), // 6 fotografando
  ];
  const sheet = new Img(20 * frames.length, 32);
  frames.forEach((f, i) => sheet.blit(f, i * 20, 0));
  return sheet;
}

// Retrato 32x32 para a caixa de diálogo
function portrait() {
  const p = new Img(32, 32, 0);
  p.disc(16, 15, 10, 1); p.rect(9, 6, 15, 6, 1);
  p.disc(17, 18, 8, 4); p.rect(10, 11, 16, 5, 1);
  p.rect(9, 9, 17, 4, 1); // franja cobre o topo do rosto
  for (let x = 10; x < 25; x += 3) p.line(x, 12, x + 1, 15, 1);
  p.rect(13, 18, 2, 2, 0); p.rect(20, 18, 2, 2, 0); p.set(13, 18, 5);
  p.line(15, 24, 19, 24, 2);
  p.rect(8, 27, 18, 5, 2); p.rect(14, 27, 6, 2, 4);
  p.frame(0, 0, 32, 32, 3);
  return p;
}

// ---------- A FIGURA (só aparece na foto) 24x60 ----------
function figure() {
  const f = new Img(24, 60);
  f.line(12, 59, 12, 18, 0, 3); f.line(10, 59, 9, 40, 0, 2); f.line(14, 59, 15, 40, 0, 2);
  f.disc(12, 10, 6, 0); f.rect(9, 16, 7, 5, 0);
  f.line(10, 20, 3, 46, 0, 2); f.line(3, 46, 1, 52, 0, 1);
  f.line(14, 20, 21, 44, 0, 2); f.line(21, 44, 23, 51, 0, 1);
  f.set(10, 9, 5); f.set(14, 9, 5); f.set(10, 10, 4); f.set(14, 10, 4);
  return f;
}

// ---------- ESTRADA (exterior com névoa) ----------
function farTrees() {
  const img = new Img(480, 180), r = rng(5);
  for (let i = 0; i < 22; i++) tree(img, r, Math.floor(r() * 480), 140, 30 + r() * 40, 1, 4);
  return img;
}
function midTrees() {
  const img = new Img(480, 180), r = rng(9);
  for (let i = 0; i < 10; i++) tree(img, r, 20 + i * 47 + Math.floor(r() * 20), 146, 60 + r() * 50, 2, i % 2 ? 2 : 3);
  return img;
}
function nearTrees() {
  const img = new Img(480, 180), r = rng(31);
  [40, 250, 410].forEach((x, i) => tree(img, rng(60 + i), x, 182, 200, 6 - i, 0));
  // capim alto na frente
  for (let x = 0; x < 480; x++) if (r() < 0.25) img.line(x, 180, x + Math.round(r() * 2 - 1), 172 - r() * 8, 0);
  return img;
}
function fogBands() {
  // faixas de névoa entre as camadas: Osso em pontos sobre transparente
  const img = new Img(480, 180), r = rng(77);
  for (let y = 96; y < 152; y++) {
    const t = 0.5 * Math.max(0, 1 - Math.abs(y - 130) / 26);
    for (let x = 0; x < 480; x++) { const n = t * (0.6 + 0.4 * Math.sin(x * 0.03 + y * 0.2)); if (bayer(x, y) < n) img.set(x, y, 5); }
  }
  return img;
}
function roadGround(width) {
  const img = new Img(width, 40), r = rng(13);
  img.rect(0, 2, width, 38, 1);
  for (let x = 0; x < width; x++) {
    img.set(x, 2, 0);
    if (r() < 0.5) img.line(x, 2, x, 2 - Math.floor(r() * 4), 0);
  }
  img.dither(0, 6, width, 34, 1, 0, 0.35);
  for (let i = 0; i < width / 6; i++) img.set(Math.floor(r() * width), 4 + Math.floor(r() * 30), 2);
  // trilha de terra mais clara
  for (let x = 0; x < width; x++) for (let y = 3; y < 8; y++) if (bayer(x, y) < 0.45) img.set(x, y, 2);
  return img;
}
function house() {
  const w = 176, h = 128, img = new Img(w, h);
  // telhado
  for (let y = 0; y < 36; y++) { const inset = Math.floor((36 - y) * 1.6); img.rect(inset, y, w - inset * 2, 1, y % 5 === 0 ? 0 : 1); }
  img.line(0, 36, w - 1, 36, 0, 2);
  // chaminé
  img.rect(130, 0, 12, 18, 0); img.rect(132, 2, 8, 14, 1);
  // paredes de tábua
  img.rect(8, 38, w - 16, h - 38, 1);
  for (let y = 40; y < h; y += 5) img.rect(8, y, w - 16, 1, 0);
  img.frame(8, 38, w - 16, h - 38, 0);
  // janelas: uma escura, uma com algo pálido atrás
  [[24, 56], [124, 56]].forEach(([x, y], i) => {
    img.rect(x, y, 28, 26, 0); img.frame(x - 2, y - 2, 32, 30, 2); img.rect(x + 13, y, 2, 26, 2); img.rect(x, y + 12, 28, 2, 2);
    if (i === 1) { img.disc(x + 7, y + 7, 3, 4); img.set(x + 6, y + 6, 0); img.set(x + 8, y + 6, 0); }
  });
  // porta
  img.rect(74, 72, 28, 56, 0); img.frame(72, 70, 32, 58, 2); img.rect(76, 76, 24, 22, 1); img.rect(76, 102, 24, 22, 1); img.rect(95, 100, 2, 3, 4);
  // degrau
  img.rect(66, h - 4, 44, 4, 2);
  return img;
}
function sign() {
  const img = new Img(18, 30);
  img.rect(8, 10, 2, 20, 0);
  img.rect(0, 2, 18, 11, 0); img.rect(1, 3, 16, 9, 3);
  img.line(3, 6, 14, 6, 1); img.line(3, 9, 11, 9, 1);
  img.line(2, 3, 5, 11, 2);
  return img;
}

// ---------- CORREDOR (interior escuro; esta é a versão "acesa", que a foto revela) ----------
function hallway() {
  const W = 640, H = 180, img = new Img(W, H, 3), r = rng(21);
  // papel de parede: listras e florzinhas em tons vizinhos (não viram contorno no escuro)
  for (let y = 16; y < 108; y++) for (let x = 0; x < W; x++) img.set(x, y, (x % 16) < 8 ? 3 : 4);
  for (let y = 22; y < 104; y += 16) for (let x = 4; x < W; x += 16) { img.set(x, y, 2); img.set(x - 1, y + 1, 2); img.set(x + 1, y + 1, 2); img.set(x, y + 2, 2); }
  // manchas de umidade
  for (let i = 0; i < 6; i++) { const cx = r() * W, cy = 30 + r() * 60; for (let k = 0; k < 160; k++) { const a = r() * 6.28, d = Math.sqrt(r()) * 14; img.set(cx + Math.cos(a) * d * 1.4, cy + Math.sin(a) * d, 2); } }
  // teto e sanca
  img.rect(0, 0, W, 14, 1); img.rect(0, 14, W, 2, 0);
  // lambri
  img.rect(0, 108, W, 40, 2); img.rect(0, 108, W, 2, 0);
  for (let x = 0; x < W; x += 32) { img.frame(x + 4, 114, 24, 28, 1); }
  // rodapé e assoalho
  img.rect(0, 146, W, 2, 0);
  for (let y = 148; y < H; y++) for (let x = 0; x < W; x++) img.set(x, y, (y % 6 === 0) ? 1 : 2);
  for (let i = 0; i < 40; i++) img.rect(Math.floor(r() * W), 149 + Math.floor(r() * 5) * 6, 1, 5, 1);
  // portas: entrada (esquerda), quarto (meio), fim do corredor (direita)
  [[24, 'saida'], [404, 'quarto'], [580, 'fim']].forEach(([x]) => {
    img.rect(x, 52, 40, 96, 0); img.frame(x - 3, 49, 46, 99, 1);
    img.rect(x + 4, 56, 32, 40, 1); img.rect(x + 4, 100, 32, 44, 1); img.rect(x + 31, 100, 3, 4, 4);
  });
  // quadros
  function picture(x, y, w, h, kind) {
    img.rect(x - 3, y - 3, w + 6, h + 6, 0); img.frame(x - 2, y - 2, w + 4, h + 4, 2);
    img.rect(x, y, w, h, 3);
    if (kind === 'face') { img.disc(x + w / 2, y + h / 2 - 2, 6, 1); img.rect(x + w / 2 - 8, y + h - 9, 17, 9, 1); }
    if (kind === 'house') { img.rect(x + 6, y + 14, 14, 10, 1); img.line(x + 4, y + 14, x + 13, y + 6, 1); img.line(x + 13, y + 6, x + 22, y + 14, 1); }
  }
  picture(170, 40, 26, 32, 'face'); picture(300, 46, 26, 22, 'house'); picture(500, 40, 26, 32, 'face');
  // arandelas apagadas
  [120, 250, 470].forEach(x => { img.rect(x, 50, 2, 8, 0); img.rect(x - 3, 44, 8, 6, 1); img.frame(x - 3, 44, 8, 6, 0); });
  // mesinha com o bilhete
  img.rect(220, 124, 34, 3, 0); img.rect(222, 127, 2, 19, 0); img.rect(250, 127, 2, 19, 0); img.rect(224, 132, 26, 2, 1);
  img.rect(230, 121, 10, 3, 5); img.line(231, 122, 238, 122, 3);
  // tapete
  img.dither(110, 150, 380, 8, 2, 1, 0.5); img.frame(110, 150, 380, 8, 1);
  return img;
}
// Olhos que aparecem no quadro só na foto
function portraitEyes() { const img = new Img(9, 3); img.set(1, 1, 5); img.set(7, 1, 5); img.set(0, 1, 4); img.set(8, 1, 4); return img; }

console.log('Gerando arte:');
save(playerSheet(), 'actors/player/player_sheet.png');
save(portrait(), 'actors/player/portrait.png');
save(figure(), 'actors/figure/figure.png');
save(farTrees(), 'levels/road/art/far_trees.png');
save(midTrees(), 'levels/road/art/mid_trees.png');
save(fogBands(), 'levels/road/art/fog.png');
save(nearTrees(), 'levels/road/art/near_trees.png');
save(roadGround(960), 'levels/road/art/ground.png');
save(house(), 'levels/road/art/house.png');
save(sign(), 'levels/road/art/sign.png');
save(hallway(), 'levels/hallway/art/hallway.png');
save(portraitEyes(), 'levels/hallway/art/portrait_eyes.png');
