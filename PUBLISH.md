# Publishing

The place for this game is **already published and Public**:
https://www.roblox.com/games/79673833446434 (place_id 79673833446434, universe_id 8420965215).

The play code in the experience description is `makefun-ladder-dugout-vine`.

## After any source change

1. Build the place from source:
   `~/workspace/makefun/rojo/rojo build default.project.json --output game.rbxl`
2. Upload `game.rbxl` over the existing place via Roblox Studio (or the Creator Dashboard's
   place upload), so the live experience matches the repo.
3. Re-run `node scripts/render-screenshots.mjs` if the world/HUD changed, so the screenshots
   match, then re-upload the thumbnail (one of the screenshots) on the Creator Dashboard.
4. Run the kit checks and hand the game in with `main.ts`.

The account's owner (the poler account) sets the experience Public and uploads the icon/thumbnail
on the Creator Dashboard as Roblox asks for (age check, genre, content questionnaire first).
