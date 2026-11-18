// render-screenshots.mjs — compose the game's 3 screenshots.
//
// HONESTY: there is no Roblox Studio on this machine, so these are COMPOSED
// RENDERS of the game's own world and HUD data (read from GameData.json), not
// captures of Roblox Studio. They draw the same brainrot cast, rarity ladder
// and HUD the game builds at runtime, using an isometric/painter's projection.
//
// Runs on Node 24, standard library only. It calls scripts/draw_scene.py
// (Python + PIL) when available to encode the PNGs; otherwise it falls back to
// a minimal PNG encoder written inline (unlikely to be needed).
import { readFileSync, writeFileSync, mkdirSync, existsSync } from "node:fs";
import { spawnSync } from "node:child_process";
import { join, dirname } from "node:path";
import { tmpdir } from "node:os";
import { fileURLToPath } from "node:url";

const here = dirname(fileURLToPath(import.meta.url));
const root = join(here, "..");
const data = JSON.parse(readFileSync(join(root, "GameData.json"), "utf8"));
const outDir = join(root, "screenshots");
mkdirSync(outDir, { recursive: true });

const W = 1280;
const H = 720;

// -------- minimal PNG encoder (fallback if PIL is unavailable) --------
function crc32(buf) {
  let c = 0xffffffff;
  for (let i = 0; i < buf.length; i++) {
    c ^= buf[i];
    for (let k = 0; k < 8; k++) c = c & 1 ? 0xedb88320 ^ (c >>> 1) : c >>> 1;
  }
  return (c ^ 0xffffffff) >>> 0;
}

function chunk(type, data) {
  const len = Buffer.alloc(4);
  len.writeUInt32BE(data.length);
  const typeBuf = Buffer.from(type, "ascii");
  const crc = Buffer.alloc(4);
  crc.writeUInt32BE(crc32(Buffer.concat([typeBuf, data])));
  return Buffer.concat([len, typeBuf, data, crc]);
}

function encodePNG(width, height, rgb) {
  const sig = Buffer.from([137, 80, 78, 71, 13, 10, 26, 10]);
  const ihdr = Buffer.alloc(13);
  ihdr.writeUInt32BE(width, 0);
  ihdr.writeUInt32BE(height, 4);
  ihdr[8] = 8; ihdr[9] = 2; ihdr[10] = 0; ihdr[11] = 0; ihdr[12] = 0;
  let raw = Buffer.alloc((width * 3 + 1) * height);
  let p = 0;
  for (let y = 0; y < height; y++) {
    raw[p++] = 0;
    for (let x = 0; x < width; x++) {
      const i = (y * width + x) * 3;
      raw[p++] = rgb[i];
      raw[p++] = rgb[i + 1];
      raw[p++] = rgb[i + 2];
    }
  }
  return Buffer.concat([sig, chunk("IHDR", ihdr), chunk("IDAT", deflate(raw)), chunk("IEND", Buffer.alloc(0))]);
}

function deflate(data) {
  // Store blocks (no compression) — valid PNG, small enough for these scenes.
  const out = [];
  const len = data.length;
  let off = 0;
  do {
    const n = Math.min(65535, len - off);
    const head = Buffer.alloc(5);
    head[0] = off === 0 ? 0x01 : 0x00;
    head.writeUInt16LE(n, 1);
    head.writeUInt16LE(n ^ 0xffff, 3);
    out.push(head, data.subarray(off, off + n));
    off += n;
  } while (off < len);
  return Buffer.concat(out);
}
// -------- end minimal PNG encoder --------

// -------- tiny painter's-algorithm rasterizer (world->screen) --------
// world: x forward (belt), z sideways, y up. Simple isometric mapping.
const floorY = 300;
const sceneDefs = []; // filled per view

function iso(cx, cy, x, y, z) {
  const sx = cx + (x - z) * 1.0;
  const sy = cy + (x + z) * 0.6 - y;
  return [Math.round(sx), Math.round(sy)];
}

const rarities = data.rarityTiers;
const brainrots = data.brainrots;
const mutations = data.mutationMultipliers;

function makeScene(width, height) {
  // returns a mutable RGB buffer and helpers
  const rgb = new Uint8Array(width * height * 3);
  const set = (x, y, r, g, b) => {
    if (x < 0 || y < 0 || x >= width || y >= height) return;
    const i = (y * width + x) * 3;
    rgb[i] = r; rgb[i + 1] = g; rgb[i + 2] = b;
  };
  const rect = (x0, y0, x1, y1, r, g, b) => {
    for (let y = y0; y <= y1; y++)
      for (let x = x0; x <= x1; x++) set(x, y, r, g, b);
  };
  return { rgb, set, rect };
}

// -------- HUD drawing helpers --------
function drawTextLines(rgb, set, W, H, x, y, lines, color) {
  const col = color || [255,255,255];
  // simple blocky text via a 5x7 font table
  const FONT = {
    A: [0x0E,0x11,0x11,0x1F,0x11], B: [0x1E,0x11,0x1E,0x11,0x1E],
    C: [0x0E,0x11,0x10,0x11,0x0E], D: [0x1C,0x12,0x11,0x12,0x1C],
    E: [0x1F,0x10,0x1E,0x10,0x1F], F: [0x1F,0x10,0x1E,0x10,0x10],
    G: [0x0E,0x10,0x17,0x11,0x0E], H: [0x11,0x11,0x1F,0x11,0x11],
    I: [0x1F,0x04,0x04,0x04,0x1F], J: [0x07,0x02,0x02,0x12,0x0C],
    K: [0x11,0x12,0x1C,0x12,0x11], L: [0x10,0x10,0x10,0x10,0x1F],
    M: [0x11,0x1B,0x15,0x11,0x11], N: [0x11,0x19,0x15,0x13,0x11],
    O: [0x0E,0x11,0x11,0x11,0x0E], P: [0x1E,0x11,0x1E,0x10,0x10],
    Q: [0x0E,0x11,0x15,0x12,0x0D], R: [0x1E,0x11,0x1E,0x12,0x11],
    S: [0x0F,0x10,0x0E,0x01,0x1E], T: [0x1F,0x04,0x04,0x04,0x04],
    U: [0x11,0x11,0x11,0x11,0x0E], V: [0x11,0x11,0x11,0x0A,0x04],
    W: [0x11,0x11,0x15,0x1B,0x11], X: [0x11,0x0A,0x04,0x0A,0x11],
    Y: [0x11,0x0A,0x04,0x04,0x04], Z: [0x1F,0x02,0x04,0x08,0x1F],
    "0": [0x0E,0x11,0x13,0x15,0x0E], "1": [0x04,0x0C,0x04,0x04,0x0E],
    "2": [0x0E,0x01,0x0E,0x10,0x1F], "3": [0x0E,0x01,0x06,0x01,0x0E],
    "4": [0x02,0x06,0x0A,0x1F,0x02], "5": [0x1F,0x10,0x0E,0x01,0x0E],
    "6": [0x06,0x08,0x0E,0x11,0x0E], "7": [0x1F,0x01,0x02,0x04,0x04],
    "8": [0x0E,0x11,0x0E,0x11,0x0E], "9": [0x0E,0x11,0x0F,0x01,0x06],
    " ": [0x00,0x00,0x00,0x00,0x00], "$": [0x0A,0x1F,0x0A,0x1F,0x0A],
    "-": [0x00,0x00,0x1F,0x00,0x00], "/": [0x01,0x02,0x04,0x08,0x10],
    "!": [0x04,0x04,0x04,0x00,0x04], ".": [0x00,0x00,0x00,0x00,0x04],
    ":": [0x00,0x04,0x00,0x04,0x00], "+": [0x04,0x04,0x1F,0x04,0x04],
    "(": [0x02,0x04,0x04,0x04,0x02], ")": [0x08,0x04,0x04,0x04,0x08],
    ",": [0x00,0x00,0x00,0x04,0x08], "*": [0x11,0x0A,0x04,0x0A,0x11],
  };
  let ty = y;
  for (const line of lines) {
    let tx = x;
    for (const ch of line.toUpperCase()) {
      const glyph = FONT[ch];
      if (glyph) {
        for (let r = 0; r < 5; r++) {
          const row = glyph[r];
          for (let c = 0; c < 5; c++) {
            if (row & (1 << (4 - c))) set(tx + c, ty + r, col[0], col[1], col[2]);
          }
        }
        tx += 7;
      }
    }
    ty += 8;
  }
}

// -------- scene 1: wide arena view (both bases, conveyor, brainrots, HUD) --------
function buildArenaScene() {
  const c = makeScene(W, H);
  // sky
  for (let y = 0; y < 300; y++) {
    const t = y / 300;
    const r = Math.round(120 + 80 * t);
    const g = Math.round(180 + 60 * t);
    const b = 220 + 35 * t;
    c.rect(0, y, W, y, r, g, b);
  }
  c.rect(0, 300, W, H, 110, 160, 90); // ground

  // conveyor belt across the middle
  c.rect(220, 470, 1060, 560, 90, 90, 100);
  for (let x = 230; x < 1060; x += 60) c.rect(x, 470, x + 40, 560, 130, 130, 140);

  // player base (left), rival base (right)
  c.rect(90, 320, 480, 640, 90, 110, 190);
  c.rect(800, 320, 1190, 640, 200, 90, 90);

  // pedestals on the player base with brainrots
  const slots = [[140,420],[260,420],[380,420],[140,540],[260,540],[380,540]];
  let i = 0;
  for (const b of brainrots.slice(0, 5)) {
    if (i >= slots.length) break;
    const [sx, sy] = slots[i]; i++;
    const col = b.color;
    c.rect(sx - 18, sy - 8, sx + 18, sy + 2, 60, 60, 60);
    c.rect(sx - 16, sy - 34, sx + 16, sy - 8, col[0]*255, col[1]*255, col[2]*255);
  }

  // brainrot walking the conveyor
  for (const b of brainrots.slice(0, 7)) {
    const sx = 480 + i * 70;
    const sy = 500 + (i % 2) * 20;
    i++;
    const col = b.color;
    c.rect(sx - 14, sy - 30, sx + 14, sy - 2, col[0]*255, col[1]*255, col[2]*255);
  }

  return c.rgb;
}

// -------- scene 2: close-up of player base with labels --------
function buildBaseScene() {
  const c = makeScene(W, H);
  for (let y = 0; y < 300; y++) {
    const t = y / 300;
    c.rect(0, y, W, y, Math.round(120+80*t), Math.round(180+60*t), Math.round(220+35*t));
  }
  c.rect(0, 300, W, H, 110, 160, 90);
  // big player base platform
  c.rect(40, 200, 1240, 700, 150, 120, 90);
  c.rect(40, 200, 1240, 300, 90, 110, 200); // back wall

  // 6 pedestals with brainrots + name/rarity/$ labels
  const slots = [[120,420],[320,420],[520,420],[720,420],[920,420],[1120,420]];
  let i = 0;
  for (const b of brainrots.slice(0, 6)) {
    const [sx, sy] = slots[i]; i++;
    const col = b.color;
    c.rect(sx - 34, sy - 20, sx + 56, sy + 4, 50, 50, 55); // label box
    c.rect(sx - 18, sy - 56, sx + 38, sy - 20, col[0]*255, col[1]*255, col[2]*255);
    // label text drawn via PIL later (scene spec carries strings)
  }
  return c.rgb;
}

// -------- scene 3: HUD + collection / rarity ladder --------
function buildHUDScene() {
  const c = makeScene(W, H);
  for (let y = 0; y < H; y++) {
    c.rect(0, y, W, y, Math.round(20+15*y/H), Math.round(22+18*y/H), Math.round(30+20*y/H));
  }
  // top-left cash panel
  c.rect(14, 14, 300, 150, 15, 15, 25);
  c.rect(340, 200, 940, 620, 20, 20, 35); // collection panel
  // rarity ladder rows
  let i = 0;
  for (const t of rarities) {
    const y = 220 + i * 55;
    c.rect(360, y, 920, y + 45, t.color[0]*255, t.color[1]*255, t.color[2]*255);
    i++;
  }
  return c.rgb;
}

function main() {
  const scenes = [buildArenaScene(), buildBaseScene(), buildHUDScene()];
  const names = ["1-start.png", "2-play.png", "3-end.png"];
  const specs = [
    {
      view: "arena",
      brainrots, rarities,
      cash: "$2,400", income: "$180/s", rebirth: "Rebirths: 3",
      banner: "BRAINROT RAIN!", golden: null,
    },
    {
      view: "base",
      brainrots, rarities,
      cash: "$7,900", income: "$412/s", rebirth: "Rebirths: 5",
      banner: null, golden: "GOLDEN HOUR x2",
    },
    {
      view: "collection",
      brainrots, rarities,
      owned: ["tung", "tralalero", "lirili", "bombardiro", "ballerina",
              "chimpanzini", "frigo", "vaca", "giraffa", "pot", "sfinge"],
      cash: "$12,300", income: "$1,020/s", rebirth: "Rebirths: 7",
      banner: null, golden: null,
    },
  ];

  // Prefer Python + PIL; fall back to the inline encoder.
  const py = spawnSync("python3", ["-c", "import PIL"]);
  if (py.status === 0) {
    for (let i = 0; i < scenes.length; i++) {
      const sceneFile = join(tmpdir(), "bbrw-scene.tmp.json");
      writeFileSync(sceneFile, JSON.stringify(specs[i]));
      const out = join(outDir, names[i]);
      const r = spawnSync("python3", [join(here, "draw_scene.py"), sceneFile, out], { cwd: here });
      const pyOut = r.stdout ? r.stdout.toString() : "";
      if (pyOut) process.stdout.write(pyOut);
      // The Python layout check (CHECK lines) enforces the precision rules:
      // no label overlap, >= 20 px between labels/HUD, everything on screen.
      // A bad layout must never be committed.
      if (pyOut.includes("OVERLAP") || pyOut.includes("OUT_OF_BOUNDS")) {
        console.error("LAYOUT CHECK FAILED for", names[i], "- fix draw_scene.py, do not commit");
        process.exit(1);
      }
      if (r.status !== 0) {
        console.error("draw_scene failed:", r.stderr && r.stderr.toString());
        fallbackWrite(scenes[i], out);
      }
    }
  } else {
    for (let i = 0; i < scenes.length; i++) {
      fallbackWrite(scenes[i], join(outDir, names[i]));
    }
  }
  console.log("wrote 3 screenshots to", outDir);
}

function fallbackWrite(rgb, out) {
  const png = encodePNG(W, H, rgb);
  writeFileSync(out, png);
  console.log("wrote (fallback)", out);
}

main();
