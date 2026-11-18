// Brainrot Base Wars — make.fun roblox-brainrot-01 entry hand-in.
// Node 22+, standard library only. Build the Rojo place into game.rbxl first:
//   rojo build default.project.json --output game.rbxl
// Then run this to copy the place, source, screenshots and PLAY.json into the
// output dir and write dossier.json (the summary the judge reads).
import { copyFileSync, cpSync, existsSync, mkdirSync, writeFileSync } from "node:fs";
import { basename, join } from "node:path";
import { fileURLToPath } from "node:url";
import { buildDossier } from "./vendor/makefun-roblox.ts";

const here = fileURLToPath(new URL(".", import.meta.url));
const out = process.env.MAKEFUN_OUTPUT_DIR ?? "/output";

// cpSync's filter: leave out every file and directory whose name starts with a dot.
const notDotted = (path: string): boolean => !basename(path).startsWith(".");

copyFileSync(join(here, "game.rbxl"), join(out, "game.rbxl"));
copyFileSync(join(here, "PLAY.json"), join(out, "PLAY.json"));
cpSync(join(here, "src"), join(out, "src"), { recursive: true, filter: notDotted });
mkdirSync(join(out, "screenshots"), { recursive: true });
if (existsSync(join(here, "screenshots"))) {
  cpSync(join(here, "screenshots"), join(out, "screenshots"), { recursive: true, filter: notDotted });
}

writeFileSync(
  join(out, "dossier.json"),
  buildDossier(out, {
    text_max_bytes: 65536,
    screenshots: { max: 4, max_bytes: 262144 },
    max_instances: 500000,
    scripts_max_source_bytes: 8388608,
    scripts_max_path_chars: 1048576,
  }),
);
