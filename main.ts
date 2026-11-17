// main.ts (Node 24, standard library only)
// Hands in the Roblox place built from this directory's Rojo project. It copies
// game.rbxl, src/, screenshots/ and PLAY.json into the output directory (default
// "out", overridable with MAKEFUN_OUTPUT_DIR) and writes dossier.json, the
// summary the judge reads. The dossier is deterministic: the same inputs always
// produce byte-identical output.

import { copyFileSync, cpSync, existsSync, mkdirSync, readFileSync, writeFileSync } from 'node:fs';
import { basename, join } from 'node:path';
import { fileURLToPath } from 'node:url';
import { buildDossier } from './vendor/makefun-roblox.ts';

const here = fileURLToPath(new URL('.', import.meta.url));
const out = process.env.MAKEFUN_OUTPUT_DIR ?? 'out';

// Exclude every file/dir whose name begins with a dot (.git, .DS_Store, .gitkeep).
const notDotted = (path: string): boolean => !basename(path).startsWith('.');

mkdirSync(out, { recursive: true });

// The binary place Rojo built from src/ + default.project.json.
copyFileSync(join(here, 'game.rbxl'), join(out, 'game.rbxl'));
copyFileSync(join(here, 'PLAY.json'), join(out, 'PLAY.json'));

// Source tree (no dotfiles).
if (existsSync(join(here, 'src'))) {
  cpSync(join(here, 'src'), join(out, 'src'), { recursive: true, filter: notDotted });
}

// Screenshots (no dotfiles). At least one is required by buildDossier.
mkdirSync(join(out, 'screenshots'), { recursive: true });
if (existsSync(join(here, 'screenshots'))) {
  cpSync(join(here, 'screenshots'), join(out, 'screenshots'), { recursive: true, filter: notDotted });
}

// The scorer's caps: keep the dossier text under 64 KiB, allow up to 4
// screenshots each under 256 KiB, and refuse a place the scorer would refuse.
writeFileSync(
  join(out, 'dossier.json'),
  buildDossier(out, {
    text_max_bytes: 65536,
    screenshots: { max: 4, max_bytes: 262144 },
    max_instances: 500000,
    scripts_max_source_bytes: 8388608,
    scripts_max_path_chars: 1048576,
  }),
);

// Confirm we produced the dossier (helps debugging; the judge only reads it).
if (!existsSync(join(out, 'dossier.json'))) {
  throw new Error('dossier.json was not written');
}