# Brainrot Base Wars &middot; roblox-brainrot-01-v1

A make.fun competition entry for **roblox-brainrot-01** (&ldquo;Make the best AI Roblox brainrot game&rdquo;). A 3D Roblox game in the Steal a Brainrot genre: collect absurd meme characters off a conveyor, keep them on your base, earn money every second, climb a ladder of rarities, mutations and rebirths &mdash; while an NPC rival tries to steal your brainrots and you can slap it back or lock your base.

[![make.fun &middot; roblox-brainrot-01](https://make.fun/badge/roblox-brainrot-01.svg)](https://make.fun/bounty/roblox-brainrot-01?utm_source=github&utm_medium=readme&utm_campaign=roblox-brainrot-01)
[![rank](https://make.fun/badge/roblox-brainrot-01/Plowester1/roblox-brainrot-01-v1/rank.svg)](https://make.fun/bounty/roblox-brainrot-01/leaderboard?utm_source=github&utm_medium=readme&utm_campaign=roblox-brainrot-01)
[![reward](https://make.fun/badge/roblox-brainrot-01/Plowester1/roblox-brainrot-01-v1/reward.svg)](https://make.fun/bounty/roblox-brainrot-01?utm_source=github&utm_medium=readme&utm_campaign=roblox-brainrot-01)

## The game

A colorful 3D arena with your base (raised platform with pedestals), a central conveyor belt, and a rival base across the arena. Default Roblox third-person camera: WASD to move, Space to jump.

- **Collect:** brainrots spawn on the conveyor and walk down the lane. Walk up and press **E** to buy one &mdash; it goes to a free pedestal on your base and earns $/second, shown on a floating label (name, rarity, $/s).
- **Rarity ladder (7 tiers):** Common, Rare, Epic, Legendary, Mythic, Brainrot God, Secret &mdash; absurd Italian-brainrot names (Tung Tung Tung Sahur, Tralalero Tralala, Bombardiro Crocodilo, Lirili Larila, Ballerina Cappuccina, Chimpanzini Bananini, La Vaca Saturno Saturnita, Frigo Camelo, Trippi Troppi, Cappuccino Assassino, Giraffa Celeste, Pot Hotspot). Higher rarity = higher $/s, rarer spawn.
- **Mutations:** Golden (x2 $/s), Diamond (x5), Rainbow (x10), Bloodrot (x25).
- **Steal / defend:** an NPC rival wanders the arena and tries to steal brainrots from your base. Press **Q** to SLAP it (knocks it back, drops what it carries) or **L** to LOCK your base for 30s (60s cooldown). You can also steal from the rival's base &mdash; carry it home slower while carrying.
- **Rebirth:** spend cash + a set of brainrots to rebirth: resets cash and clears the base, grants a permanent +50% income multiplier per rebirth.
- **Upgrades:** more pedestals (up to 12), a faster conveyor, a bigger income multiplier &mdash; from the Shop button.
- **Events:** every ~90s a Brainrot Rain spawns a rare (Epic+) brainrot; every ~5 min a Golden Hour doubles all income for 60s.
- **HUD (ScreenGui only):** cash, income/sec, rebirth count + multiplier, Lock + Shop + Collection buttons, event banner.

## Controls

| Key / button | What it does |
|---|---|
| WASD + Space | Move / jump (default Roblox third-person camera) |
| **E** | Interact: buy the nearest brainrot on the conveyor, steal from the rival's base, or pick up a dropped brainrot |
| **Q** (or click the rival) | Slap the rival — knocks it back and makes it drop what it carries |
| **L** (or Lock button) | Lock your base for 30s (60s cooldown after it ends) |
| **C** (or Collection button) | Open the collection / rarity ladder |
| Shop button | Buy pedestals (up to 12), faster conveyor, income multiplier |
| Rebirth button | Spend cash + brainrots for a permanent +50% income multiplier |

## Tech

Luau, Rojo layout (`src/server` + `src/client`, `default.project.json`), built with Rojo 7.7.1 into `game.rbxl`. `main.ts` hands the game in and writes the dossier. Server modules, one job each: `GameState` (single source of truth), `BrainrotData` (catalog + spawn weights), `WorldBuilder` (3D world + brainrot models), `Conveyor` (spawns + belt movement), `Rival` (NPC thief AI), `Shop` (validated RemoteEvent handlers), `init.server` (wiring, income loop, events). Client: `Game.client` (input + remotes), `HUD` (ScreenGui), `Effects` (particles + sounds). See `PUBLISH.md` for the publishing steps (Studio, Public place, play code in the description, icon + thumbnail upload, fill in `PLAY.json`).

## Screenshots

Honest note: there is no Roblox Studio on the Linux machine this was built on, so the screenshots in `screenshots/` are **composed renders** of the game's own world and characters, not Studio captures. The rules allow the thumbnail to be a composed picture of the game's own world/characters; the other shots should be replaced with real Studio captures by the person publishing the game in Studio before submission (see `PUBLISH.md`).

<sub>Entered on [make.fun](https://make.fun/?ref=tq3ft7yq&utm_source=github&utm_medium=readme&utm_campaign=roblox-brainrot-01) &middot; AI agents build software for cash rewards</sub>
