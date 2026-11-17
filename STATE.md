# STATE — roblox-brainrot-01-v1 "Brainrot Base Wars" (@polersyer)

Built 2026-11-18 ~04:11–04:30 WIB by Muse (own brain only: no HCNSEC,
no opencode, no external model). Recording 01a1eb59-752a-71ee-829b-f414a4288114.
Repo: ~/workspace/makefun/entries/roblox-brainrot-01-v1/ (Plowester1/roblox-brainrot-01-v1).
Competition closes Thu 2026-11-20 21:30 WIB. DO NOT push / DO NOT submit —
the coordinator does the GitHub push + submit.

## What was built (new files, written directly in this session)

- `src/server/init.server.luau` (108 lines, was a 1-line stub) — builds the
  world, wires remotes, starts conveyor + rival, income loop (1s: pay $/s,
  push state snapshot, auto-deliver carried brainrots), events loop
  (Brainrot Rain every 90s, Golden Hour every 300s for 60s), player
  join/leave cleanup (owned + carried models destroyed on leave).
- `src/server/Shop.luau` (320 lines) — validated handlers for all 6 remotes
  (buy / steal / slap / lock / rebirth / upgrade) + TryDeliver + state
  snapshots (cash, income, multiplier, lock, upgrade costs, rebirth need,
  owned ids) sent on StateUpdate.
- `src/client/Game.client.luau` (189 lines, was the 88-line grey-square
  starter) — HUD build, ContextActionService keys (E interact, Q slap,
  L lock, C collection), click-to-slap, 0.2s proximity prompt (buy / steal /
  pick-up / slap), StateUpdate handler (state, toast, banner, effects).
- `src/client/HUD.luau` (408 lines) — ScreenGui: top bar (cash, income/s,
  rebirths, Lock/Shop/Collection/Rebirth buttons), event banner, toast,
  E-prompt, Collection panel (21 brainrots + rarity weights, from GameData),
  Shop panel (3 upgrades with live costs). Top-left kept clear of Roblox's
  menu buttons.
- `src/client/Effects.luau` (83 lines) — particle bursts + engine-bundled
  sounds for Buy/Steal/Slap/Rebirth/Rain/Golden + full-screen Golden flash.
- `PUBLISH.md` — exact Studio publish steps (publish, Public, play code in
  description, icon + first thumbnail = 1-start.png, fill in PLAY.json,
  replace screenshots with real Studio captures).

## What was revised in the existing files (genuine fixes, not trivia)

- `GameState.luau` — Rebirth now returns the cleared owned records so Shop
  can destroy their models; before, rebirth left orphan brainrots standing
  on the pedestals forever.
- `BrainrotData.luau` — chooseBrainrot clamps minimumRarityIndex; an
  out-of-range value used to return nil and crash the spawn.
- `WorldBuilder.luau` — SetPedestalCount guards past the 12-slot table
  (was a nil-index error); AttachCarried heartbeat bails out when the
  carried model was destroyed instead of erroring PivotTo every frame.
- `Conveyor.luau` — Stop() now disconnects the Heartbeat; a Start-after-Stop
  used to connect a second Heartbeat and run the belt at double speed.
- `Rival.luau` — animateWalk set ABSOLUTE hip-pivot limb angles; the old
  code multiplied each limb's CFrame every frame so legs spun round.
  completeRivalSteal no longer strands the rival forever when its base is
  full (drops the brainrot as a pickup). Stolen brainrots get their label
  updated to CARRYING (was stale). Slap path destroys the carried model
  before creating the dropped replacement (was a duplicate).
- `GameData.json` — synced to BrainrotData (arena 200 not 160, conveyor
  -42/43 speed 4.2 not -40/42 speed 4.5, signs z=35 not 36, mutation None
  weight 1000 not 100 — the old value made non-mutated spawns ~10x rarer
  than the code's own table).
- `default.project.json` — CharacterAutoLoads true (the starter's false
  left players with no character in a 3D game); Baseplate lowered to y=-2
  (its top face was coplanar with the 200x200 arena floor: z-fighting);
  added StateUpdate RemoteEvent (server->client); fixed Workspace.Gravity
  to the float 196.2 (the starter's [0,-196.2,0] array failed Rojo's type
  check — the project did not build before this fix); `--` comments
  changed to `//` (JSONC).
- `main.ts` — header rewritten for the real game (the gate requires >=1
  authored line in the entrypoint; the starter's "grey square" comment is
  gone). Logic untouched.
- `README.md` — Controls table + real module map added; make.fun badges
  KEPT; Screenshots honesty note kept.
- `TOUR.json` — steps now E (buy) then C (collection) instead of the
  starter's arrow keys.
- `scripts/render-screenshots.mjs` — HUD incomes now computed from
  GameData.json (old hardcoded 38/174/410 did not match the brainrots
  drawn: now 73/360/512 per rebirth multiplier); collection grid pitch
  70px so all 21 cards fit (21st was cut off); title "BRAINROT BASE
  WARS"; banner "GOLDEN HOUR EVENT"; fake "collection bonus +10%" footer
  replaced with the real "REBIRTH +50% INCOME EACH".

## Verification (measured, 2026-11-18 ~04:30 WIB)

1. `rojo build` — OK. game.rbxl 38,637 bytes, binary (`<roblox!` magic).
2. `main.ts` twice (out, out2) — `diff dossier.json` EMPTY (byte-identical).
   Dossier 186,527 bytes. Place block: 30 instances, 11 scripts, 93,043
   source bytes, 93.4% matched to src/ (10 of 11 scripts; the unmatched one
   is the GameData.json ModuleScript, as expected — bar is 80%).
3. `makefun.mjs check` (commit + --worktree) — 4 pass (competition_open,
   snapshot 26 files / 321,280 bytes, license_osi MIT, entrypoint),
   1 FAIL: play_link (EXPECTED — PLAY.json still has the starter zeros;
   see below), 16 skip (transcript checks run server-side), 5 at-submission
   rows pending push. "not ready: fix play_link".
4. Screenshots — 3 PNGs, 1280x720 each, 21,974 / 27,261 / 37,612 bytes
   (all ≤256 KiB), valid PNG. Re-rendered in this session. Visually
   checked 1-start.png, 2-play.png, 3-end.png after fixes.
5. Play-code check (`check --repo ... --play-code 0`) — did NOT print the
   code in this kit run (no `makefun-...` string in its output, plain or
   --json); the code itself comes from the brief: makefun-ladder-dugout-vine
   (code 0 of 4), already written in PUBLISH.md for the description.
6. Luau balance check (block/paren heuristic, /tmp/luau-balance.mjs) —
   all 10 .luau files OK. NOTE: no real Luau compiler exists on this VM
   (the /opt/hatch "luau" connector is a social-events app, name collision),
   so this is a balance check, not a compile. The gate's luau_compiles row
   is non-deciding. A Studio Play test is still the real check.

## Known gaps / left for the publisher (NOT done, NOT faked)

- PLAY.json is still zeros — the game is NOT published. Needs Roblox
  Studio + the user's account (PUBLISH.md steps 1–5): publish, set Public,
  play code in description, icon + thumbnail upload, fill in PLAY.json.
- Screenshots are COMPOSED RENDERS, not Studio captures (no Studio on
  this VM). Honest note in README + render script + PUBLISH.md step 6:
  replace with real Studio captures before submitting; re-upload
  1-start.png as first thumbnail if it changes.
- No Studio test, playtest, or publish happened. The game logic was
  verified by reading + the checks above, not by running in Roblox.
- .makefun/owner.json untouched (poler wallet FcdRcTG3QNRUFVqUm61wSxuxGQZ7jD1RpPhmZniY9fU7).
- No secrets in the repo; no real-money spending.
