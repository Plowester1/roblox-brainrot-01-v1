# Publishing Brainrot Base Wars (roblox-brainrot-01-v1)

This game cannot be published from the Linux build machine: there is no
Roblox Studio on it. The person with the Roblox account does these steps in
Roblox Studio on their own computer. The account must be at least 2 days old
and past Roblox's one-time age check, or publishing to Public is blocked.

## 1. Open the place in Studio

1. On the build machine, the repo's `game.rbxl` is already built
   (`rojo build default.project.json --output game.rbxl`).
2. Copy `game.rbxl` to the publishing computer and open it in Roblox Studio.
3. Check the world loads: green arena, blue YOUR BASE at the south end, red
   RIVAL BASE at the north end, the conveyor between them, the RivalBot.
4. Press Play in Studio once and confirm: the HUD shows cash/income, a
   brainrot walks down the conveyor, E buys it, Q slaps the rival.

## 2. Publish as a new experience

1. In Studio: **File > Publish to Roblox As...** > **Create new experience**.
2. Name: **Brainrot Base Wars**. Genre: **Tycoon** (or Obby & Platformer if
   Tycoon is unavailable). Device: Computer + Phone.
3. Answer Roblox's content questions (a simple game: answer "No" to the
   age-restricted-content question, which ends the questionnaire there).
4. In **Game Settings > Basic Info**, set the description to include the
   play code exactly, on its own line (do NOT write it as a web address —
   Roblox refuses descriptions that read like a URL):

   ```
   makefun-ladder-dugout-vine
   ```

   Suggested description text around it:

   > Brainrot Base Wars — collect absurd meme brainrots off the conveyor,
   > grow your base, and stop the rival from stealing them!
   > makefun-ladder-dugout-vine

5. **Save** the place over the same experience after any later rebuild
   (File > Publish to Roblox, same experience).

## 3. Set it Public

1. Open the Creator Dashboard: https://create.roblox.com/dashboard/creations
2. Select the experience > **Configure** (or the experience's settings).
3. Set visibility to **Public** and save. (Only the account owner can do
   this; a Private/Playtest experience is refused by make.fun.)

## 4. Icon + thumbnail (both required, both must pass Roblox review)

1. In the Creator Dashboard, select the experience, open **Configurations**,
   then **Places**, choose its start place (marked with a star).
2. **Icon**: upload a square picture (512x512 is best). Use
   `screenshots/1-start.png` cropped square, or any square render of the
   game's own world/characters. Roblox's default picture never counts.
3. **Thumbnails**: on the Experience Detail Page tab, upload
   `screenshots/1-start.png` FIRST (it must be the first thumbnail, and it
   must be the same picture as one of the screenshots in the submitted
   commit). You may add `2-play.png` / `3-end.png` after it.
4. Wait until the experience's public page on Roblox shows the icon AND the
   thumbnail — Roblox reviews each upload, and the entry is refused while
   either is missing or still in review.

## 5. Fill in PLAY.json

1. From the experience's public page URL
   `https://www.roblox.com/games/<placeId>/...`, take `<placeId>`.
2. From the Creator Dashboard experience URL
   `https://create.roblox.com/dashboard/creations/experiences/<universeId>/...`,
   take `<universeId>` (also `game.GameId` in Studio; `game.PlaceId` is the
   place id).
3. Edit `PLAY.json` in the repo:

   ```json
   {"url": "https://www.roblox.com/games/<placeId>", "place_id": <placeId>, "universe_id": <universeId>}
   ```

   Do NOT invent ids — the zeros in the starter fail the gate.
4. Commit, rebuild `game.rbxl` if the place changed, re-render screenshots
   if needed, and re-run the verification (see STATE.md).

## 6. Replace the screenshots with real Studio captures (strongly advised)

The screenshots in `screenshots/` are **composed renders**, not Studio
captures — the build machine has no Studio. The rules allow the thumbnail
to be composed, but the other shots must be Studio captures to be safe in
finalist review. Before submitting:

1. In Studio, press Play, take 3 captures (1280x720, each ≤256 KiB):
   `1-start.png` (wide arena view), `2-play.png` (close-up of your base
   with brainrot labels), `3-end.png` (Collection panel open, key C).
2. Keep the HUD text clear of the top-left corner (Roblox's menu buttons
   sit there) and take each capture while the game is running.
3. Replace the files in `screenshots/` and re-run the checks in STATE.md.
4. Re-upload `1-start.png` as the first thumbnail if it changed.
