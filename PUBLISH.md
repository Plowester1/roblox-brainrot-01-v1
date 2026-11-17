# Publishing Brainrot Base Wars

The place is **already published and Public** on Roblox under the @polersyer
account. The experience IDs live in `PLAY.json`.

- **URL:** https://www.roblox.com/games/79673833446434
- **Place ID:** 79673833446434
- **Universe ID:** 8420965215
- **Play code:** `makefun-ladder-dugout-vine` (code 0 of 4), in the experience
  description.

## Uploading a new version

Each build of the game is produced as a binary `game.rbxl` with Rojo:

    ~/workspace/makefun/rojo/rojo build default.project.json --output game.rbxl

To push a fresh build to the live place, upload `game.rbxl` as a new version
through the Creator Dashboard (Create → Brainrot Base Wars → … → Upload/Version)
or the Open Cloud Assets API. Keep the experience set to **Public** so the
judge and anyone with the play link can play it.

## Play code

The play code is written in the experience description. If it is ever missing,
re-add the exact string `makefun-ladder-dugout-vine` anywhere in the
description; the submission checker only needs it present.