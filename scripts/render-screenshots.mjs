// render-screenshots.mjs
// Composed renders of Brainrot Base Wars for the make.fun screenshots badge.
// Node 24 stdlib only. Reads the same brainrot data the game uses (GameData.json)
// and renders 3 views (1280x720 PNG) via a small Python+PIL helper
// (scripts/draw_scene.py). These are COMPOSED RENDERS, not Roblox Studio captures.

import { readFileSync, writeFileSync, mkdirSync } from 'node:fs';
import { execFileSync } from 'node:child_process';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';

const here = dirname(fileURLToPath(import.meta.url));
const root = join(here, '..');

// The brainrot data the game uses.
const data = JSON.parse(readFileSync(join(root, 'src', 'shared', 'GameData.json'), 'utf8'));
const tiers = data.tiers;
const catalog = data.catalog;
const order = data.tier_order;

// World layout, mirroring WorldBuilder.Luau.
const LAYOUT = {
  Arena: { x: 60, z: 130 },
  ConveyorZStart: -42,
  ConveyorZEnd: 42,
  ConveyorWidth: 8,
  PlayerBaseZ: 56,
  RivalBaseZ: -56,
  BasePlatform: { x: 26, y: 3, z: 14 },
};

function nameFor(tier, idx) {
  const pool = catalog.filter((e) => e.tier === tier);
  return pool[idx % pool.length].name;
}
const tierColor = (t) => (tiers[t] ? tiers[t].color : [255, 255, 255]);

const scene = (bg, proj, hud) => ({ bg, proj, hud, shapes: [] });
function addBox(s, x, y, z, dx, dy, dz, color) {
  s.shapes.push({ type: 'box', pos: [x, y, z], size: [dx, dy, dz], color: color });
}
function addText(s, x, y, z, text, color) {
  s.shapes.push({ type: 'text', pos: [x, y, z], text, color: color || [255, 255, 255] });
}

// A brainrot character: a colored block + name/rarity/$/s label above.
function addBrainrot(s, x, y, z, tier, name, mutation) {
  const color = tierColor(tier);
  addBox(s, x, y, z, 2, 2.2, 2, color);
  const mult = mutation && data.mutations[mutation] ? data.mutations[mutation].mult : 1;
  const dps = Math.round((tiers[tier] ? tiers[tier].base_money : 10) * mult);
  const mutTag = mutation && mutation !== 'None' ? ` [${mutation}]` : '';
  addText(s, x, y + 2.6, z, `${name}${mutTag}\n${tier}  $${dps}/s`, [255, 255, 255]);
}

// --- Common HUD for the 3D views ----------------------------------------
function defaultHud(banner) {
  return {
    panel: { x: 16, y: 16, w: 240, h: 140 },
    title: 'BRAINROT BASE WARS',
    cash: '$240',
    income: '$14/s',
    rebirth: 'Rebirths: 0 (x1.0)',
    banner: banner || null,
    buttons: [
      { text: 'LOCK', color: [220, 80, 90], w: 120 },
      { text: 'SHOP', color: [90, 140, 220], w: 110 },
      { text: 'COLLECTION', color: [150, 100, 220], w: 130 },
    ],
  };
}

// --- Scene 1: wide arena view --------------------------------------------
function buildArena() {
  const s = scene([140, 190, 235], { scale: 4.2, cx: 640, cy: 470, view: 1 }, defaultHud());
  // Arena floor + conveyor + both bases.
  addBox(s, 0, 0, 0, LAYOUT.Arena.x, 1, LAYOUT.Arena.z, [96, 150, 78]);
  const convLen = Math.abs(LAYOUT.ConveyorZEnd - LAYOUT.ConveyorZStart) + 12;
  addBox(s, 0, 1, 0, LAYOUT.ConveyorWidth, 0.8, convLen, [70, 70, 78]);
  addBox(s, 0, 1.5, LAYOUT.PlayerBaseZ, LAYOUT.BasePlatform.x, 3, LAYOUT.BasePlatform.z, [84, 130, 200]);
  addBox(s, 0, 1.5, LAYOUT.RivalBaseZ, LAYOUT.BasePlatform.x, 3, LAYOUT.BasePlatform.z, [180, 80, 90]);
  // Trees.
  for (const [tx, tz] of [[-22, 40], [22, -40], [-24, -45], [24, 45]]) {
    addBox(s, tx, 2, tz, 4, 3, 4, [52, 130, 60]);
  }
  // Brainrots on the conveyor.
  addBrainrot(s, -1.5, 2, -24, 'Rare', nameFor('Rare', 0), 'None');
  addBrainrot(s, 1.5, 2, 4, 'Common', nameFor('Common', 0), 'Golden');
  addBrainrot(s, -1.5, 2, 22, 'Epic', nameFor('Epic', 0), 'None');
  // Brainrots on the player base pedestals.
  addBrainrot(s, -4.5, 4.8, LAYOUT.PlayerBaseZ + 2.5, 'Common', nameFor('Common', 1), 'None');
  addBrainrot(s, -1.5, 4.8, LAYOUT.PlayerBaseZ + 2.5, 'Rare', nameFor('Rare', 1), 'Diamond');
  addBrainrot(s, 1.5, 4.8, LAYOUT.PlayerBaseZ + 2.5, 'Legendary', nameFor('Legendary', 0), 'None');
  return s;
}

// --- Scene 2: player base close-up ---------------------------------------
function buildBase() {
  const s = scene([150, 195, 240], { scale: 8, cx: 640, cy: 430, view: 1.3, ox: 0, oz: LAYOUT.PlayerBaseZ }, defaultHud());
  addBox(s, 0, 0, 0, 30, 1, 26, [96, 150, 78]);
  addBox(s, 0, 1.5, 0, LAYOUT.BasePlatform.x, 3, LAYOUT.BasePlatform.z, [84, 130, 200]);
  // Pedestals with brainrots (two rows).
  const rows = [
    [[-4.5, 2.5, 'Common', 1], [-1.5, 2.5, 'Rare', 1], [1.5, 2.5, 'Epic', 0], [4.5, 2.5, 'Mythic', 0]],
    [[-4.5, -2.5, 'Rare', 2], [-1.5, -2.5, 'Legendary', 1], [1.5, -2.5, 'Common', 0], [4.5, -2.5, 'Brainrot God', 0]],
  ];
  for (const row of rows) {
    for (const [x, z, tier, idx] of row) {
      addBox(s, x, 3.4, z, 2.2, 0.4, 2.2, [220, 220, 230]);
      const mutation = tier === 'Rare' ? 'Golden' : 'None';
      addBrainrot(s, x, 4.6, z, tier, nameFor(tier, idx), mutation);
    }
  }
  return s;
}

// --- Scene 3: HUD + collection / rarity ladder ---------------------------
function buildHud() {
  const s = scene([24, 28, 36], { scale: 0, cx: 0, cy: 0, view: 0 }, defaultHud());
  // Rarity ladder rows.
  let yy = 230;
  for (const tier of order) {
    const color = tierColor(tier);
    addText(s, 0, 0, 0, `${tier}: collected`, color);
    yy += 40;
  }
  return s;
}

// --- Render ---------------------------------------------------------------
const scenes = [
  { file: '1-arena.png', build: buildArena },
  { file: '2-base.png', build: buildBase },
  { file: '3-hud.png', build: buildHud },
];

mkdirSync(join(root, 'screenshots'), { recursive: true });

for (const item of scenes) {
  const s = item.build();
  const tmp = join(here, '.scene.tmp.json');
  writeFileSync(tmp, JSON.stringify(s));
  const out = join(root, 'screenshots', item.file);
  try {
    execFileSync('python3', ['draw_scene.py', tmp, out], { cwd: here, stdio: 'inherit' });
  } catch (e) {
    console.error('failed to render', item.file, e.message);
  }
  writeFileSync(tmp, '');
}
console.log('render-screenshots done');