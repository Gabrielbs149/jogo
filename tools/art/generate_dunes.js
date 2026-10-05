// Gera o terreno de dunas (levels/ethera/art/dunes.obj). Rodar 1 vez: node tools/art/generate_dunes.js
// O centro (a arena da batalha) fica quase plano; em volta, dunas de crista suave que crescem até o horizonte.
// É um asset como outro qualquer: dá para trocar por um terreno feito no Blender com o mesmo nome.
'use strict';
const fs = require('fs'), path = require('path');

const SIZE = 180;          // metros de lado
const STEP = 1.0;          // resolução da malha
const ARENA = { w: 32, d: 26, fade: 14 }; // área quase plana no meio (a grade da batalha mede 28.8 x 22.4)

function smoothstep(a, b, x) { const t = Math.min(Math.max((x - a) / (b - a), 0), 1); return t * t * (3 - 2 * t); }
function hash(x, y) { const s = Math.sin(x * 127.1 + y * 311.7) * 43758.5453; return s - Math.floor(s); }
function noise(x, y) {
  const xi = Math.floor(x), yi = Math.floor(y), xf = x - xi, yf = y - yi;
  const u = xf * xf * (3 - 2 * xf), v = yf * yf * (3 - 2 * yf);
  const a = hash(xi, yi), b = hash(xi + 1, yi), c = hash(xi, yi + 1), d = hash(xi + 1, yi + 1);
  return a + (b - a) * u + (c - a) * v + (a - b - c + d) * u * v;
}
function fbm(x, y) { let s = 0, a = 0.5, f = 1; for (let i = 0; i < 4; i++) { s += a * noise(x * f, y * f); f *= 2.1; a *= 0.5; } return s; }

function height(x, z) {
  // vento vindo de um ângulo fixo: cristas perpendiculares a ele
  const ang = 0.55, u = x * Math.cos(ang) + z * Math.sin(ang), v = -x * Math.sin(ang) + z * Math.cos(ang);
  const warp = fbm(x * 0.012, z * 0.012) * 9;
  // crista assimétrica: subida longa, descida curta (como duna de verdade)
  let t = (u * 0.045 + warp + Math.sin(v * 0.03) * 1.2) % 1; if (t < 0) t += 1;
  const crest = t < 0.72 ? smoothstep(0, 0.72, t) : 1 - smoothstep(0.72, 1, t);
  const big = Math.pow(crest, 1.5) * 7.5;
  const medium = (0.5 + 0.5 * Math.sin(u * 0.11 + v * 0.05 + warp * 2)) * 1.6;
  const small = fbm(x * 0.06, z * 0.06) * 1.2;
  let h = big + medium + small;
  // dunas crescem com a distância (horizonte mais dramático)
  const dist = Math.sqrt(x * x + z * z);
  h *= 1 + smoothstep(30, 90, dist) * 1.6;
  // arena + vale até o acampamento ao sul: quase planos, ondulação de no máximo ~30 cm
  const dx = Math.max(Math.abs(x) - ARENA.w / 2, 0), dz = Math.max(Math.abs(z) - ARENA.d / 2, 0);
  const arena = Math.sqrt(dx * dx + dz * dz);
  const vx = Math.max(Math.abs(x - Math.sin(z * 0.08) * 3) - 5, 0), vz = Math.max(Math.abs(z - 26) - 14, 0);
  const valley = Math.sqrt(vx * vx + vz * vz);
  const camp = Math.max(Math.hypot(x - 1, z - 34) - 9, 0);
  const outside = Math.min(arena, valley, camp);
  const gentle = 0.18 * Math.sin(x * 0.35) * Math.cos(z * 0.28) + 0.12 * fbm(x * 0.2, z * 0.2);
  const m = smoothstep(0, ARENA.fade, outside);
  return gentle * (1 - m) + (h - 2.2) * m;
}

const n = Math.round(SIZE / STEP) + 1, half = SIZE / 2;
const verts = [], norms = [], uvs = [];
for (let j = 0; j < n; j++) for (let i = 0; i < n; i++) {
  const x = -half + i * STEP, z = -half + j * STEP, y = height(x, z);
  const e = 0.5, hx = height(x + e, z) - height(x - e, z), hz = height(x, z + e) - height(x, z - e);
  const nx = -hx, ny = 2 * e, nz = -hz, l = Math.hypot(nx, ny, nz);
  verts.push(`v ${x.toFixed(3)} ${y.toFixed(3)} ${z.toFixed(3)}`);
  norms.push(`vn ${(nx / l).toFixed(4)} ${(ny / l).toFixed(4)} ${(nz / l).toFixed(4)}`);
  uvs.push(`vt ${(i / (n - 1)).toFixed(4)} ${(j / (n - 1)).toFixed(4)}`);
}
const faces = [];
for (let j = 0; j < n - 1; j++) for (let i = 0; i < n - 1; i++) {
  const a = j * n + i + 1, b = a + 1, c = a + n, d = c + 1;
  // sentido anti-horário visto de cima (normal para +Y)
  faces.push(`f ${a}/${a}/${a} ${c}/${c}/${c} ${b}/${b}/${b}`);
  faces.push(`f ${b}/${b}/${b} ${c}/${c}/${c} ${d}/${d}/${d}`);
}
const out = path.join(process.cwd(), 'levels/ethera/art/dunes.obj');
fs.mkdirSync(path.dirname(out), { recursive: true });
fs.writeFileSync(out, ['# Dunas geradas por tools/art/generate_dunes.js', 'o Dunes', ...verts, ...uvs, ...norms, 's 1', ...faces].join('\n') + '\n');
console.log(`ok ${out} (${n * n} vértices, ${faces.length} triângulos)`);
