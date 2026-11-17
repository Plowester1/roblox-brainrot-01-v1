# Brainrot Base Wars

A 3D Roblox game for the make.fun competition **"Make the best AI Roblox brainrot
game"** (FREE entry, $1,000 pot, 1st place $150). Account: **@polersyer**.

Collect absurd Italian-brainrot meme characters, earn money per second, and defend
your base from a rival who steals your brainrots.

## The game loop

- A colorful **3D arena**: your raised base with pedestals on one side, the rival
  base across the arena, and a central conveyor belt running between them.
- **Brainrots** spawn on the conveyor and walk down the lane. Walk up to one and
  press **E** to buy it (costs cash); it goes to a free pedestal on your base.
- Each brainrot earns **$/second**, shown in a floating label above it: name,
  rarity, $/s. There are **7 rarity tiers** — Common, Rare, Epic, Legendary,
  Mythic, Brainrot God, Secret — with names like *Tung Tung Tung Sahur*,
  *Tralalero Tralala*, *Bombardiro Crocodilo*, *Ballerina Cappuccina*.
- **Mutations**: a brainrot can spawn **Golden** (x2 $/s), **Diamond** (x5),
  **Rainbow** (x10), or **Bloodrot** (x25), shown in its label and tint.
- **Tension**: an NPC rival bot wanders the arena and steals brainrots from your
  base. Press **Q** to slap it (it drops what it carries), or press **L** to lock
  your base for 30s (60s cooldown) so it cannot steal. You can also steal from
  the rival base — but you move slower while carrying.
- **Rebirths**: spend cash + your brainrots to rebirth, resetting the base but
  granting a permanent +50% income multiplier per rebirth.
- **Upgrades** (Shop button): more pedestals (up to 12), a faster conveyor, and a
  bigger income multiplier.
- **Events**: every ~90s a **Brainrot Rain** spawns an Epic+ brainrot; every
  ~5 minutes **Golden Hour** doubles all income for 60s. Banners announce them.

## Controls

- **WASD** — move, **Space** — jump (default third-person camera)
- **E** — buy a brainrot / steal from the rival base
- **Q** — slap the rival bot
- **L** — lock your base (30s, 60s cooldown)
- **HUD buttons** — Lock, Shop, Collection

## Roblox place

Published and Public. See [`PUBLISH.md`](PUBLISH.md) for the place/universe IDs
and how to upload a fresh `.rbxl` version.

## Screenshots

> **Note:** the screenshots in `screenshots/` are **composed renders** generated
> by a headless script (`scripts/render-screenshots.mjs`) — they are **not**
> Roblox Studio captures. This Linux build has no Studio, so they are rendered
> approximations of the game's world and HUD. The game itself is a real 3D Roblox
> place.

## make.fun

Built for the [make.fun bounty: make the best AI Roblox brainrot game](
https://make.fun/bounty/roblox-brainrot-01). Three badges are claimed on the
submission: the game link badge (this published Public place), the play-code
badge, and the screenshots badge.

## License

MIT — see [`LICENSE`](LICENSE).