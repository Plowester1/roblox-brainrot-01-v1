#!/usr/bin/env node
// render-screenshots.mjs (Node 24, stdlib only)
// Headless, deterministic composer for the three Brainrot Base Wars screenshots.
// These are COMPOSED isometric renders built with Python + PIL -- they are NOT
// Roblox Studio captures (there is no Studio on this VM). Reads the same shared
// brainrot data the game uses (src/shared/GameData.json), builds a deterministic
// scene, and renders 1280x720 PNGs into screenshots/.

import { readFileSync, writeFileSync, existsSync } from 'node:fs';
import { join } from 'node:path';
import { spawnSync } from 'node:child_process';
import { fileURLToPath } from 'node:url';

const here = fileURLToPath(new URL('.', import.meta.url));
const root = join(here, '..');
const dataPath = join(root, 'src', 'shared', 'GameData.json');

if (!existsSync(dataPath)) {
  console.error('GameData.json not found:', dataPath);
  process.exit(1);
}

const data = JSON.parse(readFileSync(dataPath, 'utf8'));
const game = data.game;
const rarities = data.rarities;
const brainrots = data.brainrots;

// A stable (deterministic) selection of owned brainrots for the demo HUD.
const owned = [0, 4, 9, 10, 13]; // indexes into brainrots

const rarityColor = (name) => {
  for (const r of rarities) if (r.name === name) return r.color;
  return [180, 180, 180];
};

// ----- deterministic scene geometry --------------------------------------
// World layout matches the game: player base z=-44, rival base z=+44, conveyor z=0.
const boxes = [];
const labels = [];

// Ground is drawn by the Python side. Base platforms:
boxes.push({ pos: [0, 0, -44], size: [44, 3, 16], color: [46, 120, 210], view: 1 });
boxes.push({ pos: [0, 0, 44], size: [44, 3, 16], color: [200, 60, 60], view: 1 });
// Conveyor:
boxes.push({ pos: [0, 0, 0], size: [10, 1, 80], color: [110, 112, 122], view: 1 });
// Boundary walls:
boxes.push({ pos: [0, 4, 52], size: [70, 6, 2], color: [70, 72, 88], view: 1 });
boxes.push({ pos: [0, 4, -52], size: [70, 6, 2], color: [70, 72, 88], view: 1 });
boxes.push({ pos: [34, 4, 0], size: [2, 6, 104], color: [70, 72, 88], view: 1 });
boxes.push({ pos: [-34, 4, 0], size: [2, 6, 104], color: [70, 72, 88], view: 1 });

// Pedestals (small cubes) for the player base row at z=-36.
for (let i = 0; i < 6; i++) {
  const x = (i - 2.5) * 3.4;
  boxes.push({ pos: [x, 0, -36], size: [2.4, 5, 2.4], color: [70, 74, 90], view: 1 });
}

// Owned brainrots standing on the player pedestals, with name/rarity/$s labels.
const placedNames = new Set();
let pedIdx = 0;
for (const oi of owned) {
  const b = brainrots[oi];
  const col = b.color;
  const x = (pedIdx - 2.5) * 3.4;
  const z = -36;
  boxes.push({ pos: [x, 0, z], size: [2.2, 3.4, 2.2], color: col, view: 1 });
  boxes.push({ pos: [x, 3.4, z], size: [2.6, 3.6, 2.6], color: col, view: 1 });
  const rc = rarityColor(b.rarity);
  labels.push({ pos: [x, 7, z], text: b.name + ' [' + b.rarity + '] $' + b.income + '/s', color: [255, 255, 255], view: 1 });
  labels.push({ pos: [x, 6, z], text: b.rarity, color: rc, view: 1 });
  placedNames.add(b.name);
  pedIdx++;
}

// A couple of brainrots wandering the conveyor for scene 1.
boxes.push({ pos: [0, 0, -14], size: [2.4, 3.4, 2.4], color: brainrots[1].color, view: 1 });
boxes.push({ pos: [0, 0, -2], size: [2.4, 3.4, 2.4], color: brainrots[5].color, view: 1 });
boxes.push({ pos: [0, 0, 12], size: [2.4, 3.4, 2.4], color: brainrots[3].color, view: 1 });
labels.push({ pos: [0, 6, -14], text: brainrots[1].name, color: [255, 255, 255], view: 1 });
labels.push({ pos: [0, 6, -2], text: brainrots[5].name, color: [255, 255, 255], view: 1 });
labels.push({ pos: [0, 6, 12], text: brainrots[3].name, color: [255, 255, 255], view: 1 });

// Scene 2: a tight crop of the player base row (bigger, more readable labels).
for (let i = 0; i < 4; i++) {
  const oi = owned[i];
  const b = brainrots[oi];
  const x = (i - 1.5) * 10;
  boxes.push({ pos: [x, 0, -36], size: [2.4, 5, 2.4], color: [70, 74, 90], view: 2 });
  boxes.push({ pos: [x, 0, -36], size: [2.2, 3.4, 2.2], color: b.color, view: 2 });
  boxes.push({ pos: [x, 3.4, -36], size: [2.6, 3.6, 2.6], color: b.color, view: 2 });
  const rc = rarityColor(b.rarity);
  labels.push({ pos: [x, 7, -36], text: b.name + ' [' + b.rarity + '] $' + b.income + '/s', color: [255, 255, 255], view: 2 });
  labels.push({ pos: [x, 0, -36], text: b.rarity, color: rc, view: 2 });
}

const scene = {
  scale: 4.2,
  origin: [640, 400],
  boxes,
  labels,
  hud: {
    cash: '$1,240',
    income: '$62/s x1.0',
    title: 'Rebirth 0 - Noob',
  },
  rarities: rarities.map((r) => ({
    name: r.name,
    color: r.color,
    brainrots: brainrots.filter((b) => b.rarity === r.name).map((b) => ({
      name: b.name,
      income: b.income,
      owned: placedNames.has(b.name),
    })),
  })),
};

const scenePath = join(root, '.scene.tmp.json');
writeFileSync(scenePath, JSON.stringify(scene));

const drawPath = join(root, 'scripts', 'draw_scene.py');
const res = spawnSync('python3', [drawPath, scenePath], { encoding: 'utf8' });
if (res.error) {
  console.error('Failed to run python3:', res.error.message);
  process.exit(1);
}
if (res.status !== 0) {
  console.error(res.stdout, res.stderr);
  process.exit(res.status);
}
console.log('Screenshots rendered into screenshots/.');