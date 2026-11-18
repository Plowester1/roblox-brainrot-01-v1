# Brainrot Base Wars

A 3D Roblox brainrot game entered in make.fun's **"Make the best AI Roblox brainrot game"**
bounty (roblox-brainrot-01, FREE entry, $1,000 pot). A Steal-a-Brainrot-style experience:
you collect absurd meme characters, each earning money every second, and defend your base
from a rival who tries to steal your collection.

## The loop (a real 3D game)

- A 3D world: your raised base with pedestals, a moving conveyor belt down the middle, and the
  rival's base across the arena. Move with WASD, jump with Space, under the default third-person
  camera. The on-screen HUD is an overlay, never the game itself.
- Brainrots spawn on the conveyor and walk toward you. Walk up and press **E** to buy one
  (it costs cash) and it hops onto a free pedestal on your base. Every owned brainrot earns
  **$/second**, shown as a floating label above it: name, rarity, $/s.
- A **rarity ladder** of 7 tiers: Common, Rare, Epic, Legendary, Mythic, Brainrot God, Secret,
  with absurd Italian-brainrot names (Tung Tung Tung Sahur, Tralalero Tralala, Bombardiro
  Crocodilo, La Vaca Saturno Saturnita, Cappuccino Assassino, Giraffa Celeste, Pot Hotspot,
  Sfinge Pinguino, and more). Higher rarity = higher $/s and rarer spawns.
- **Mutations**: a brainrot can spawn Golden (x2 $/s), Diamond (x5), Rainbow (x10) or
  Bloodrot (x25). The label shows the mutation and the model is tinted.
- **Stealing / tension**: an NPC rival wanders the arena and steals brainrots off your base,
  carrying them back to its own. Press **Q** (or click) to **SLAP** it, knocking it back and
  making it drop what it carries. Press **L** (or the Lock button) to lock your base for 30s
  (60s cooldown); while locked the rival cannot steal. You can also walk to the rival's base
  and press **E** on what it carries to steal it back onto a free pedestal.
- **Rebirths**: spend cash and owned brainrots to rebirth. Rebirth resets cash and clears the
  base but grants a permanent **+50% income** per rebirth and a new title.
- **Upgrades** (Shop button): more pedestals (up to 12), a faster conveyor, and a bigger income
  multiplier.
- **Events**: every ~80s a **Brainrot Rain** spawns an Epic+ brainrot with a fanfare; every few
  minutes a **Golden Hour** doubles all income for 60s. Events flash a banner on the HUD.
- The **HUD** shows cash, income/sec, rebirth count + multiplier, Lock (with cooldown), Shop,
  and a Collection panel (the rarity ladder and which brainrots you own). Every button works.

## Controls

- WASD — move, Space — jump
- E — buy the brainrot you're standing next to (or steal it back from the rival base)
- Q — SLAP the rival
- L — LOCK your base (30s, 60s cooldown)
- Mouse click — also slaps the rival

## Screenshots

The three images in `screenshots/` are **composed renders** of the game's own world and HUD
data (drawn from the same `GameData.json` the game reads), not Roblox Studio captures — there
is no Studio on the build machine. They show the arena, your base with its brainrot labels, and
the HUD/collection ladder so the game loop is clear. The first (`1-start.png`) is intended as
the game's Roblox thumbnail.

## Build

- `rojo build default.project.json --output game.rbxl` — builds the place.
- `node scripts/render-screenshots.mjs` — regenerates the composed screenshots.
- `mkdir -p out && MAKEFUN_OUTPUT_DIR=out node main.ts` — hands the game in (writes `out/dossier.json`).

See `PUBLISH.md` for the publish steps for the already-published place.

MIT License — see `LICENSE`. 3 make.fun badges: the game loop, the rarity ladder + tension, and
the thumbnail. Bounty link: make.fun/c/roblox-brainrot-01.
