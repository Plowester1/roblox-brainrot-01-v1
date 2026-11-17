# Publishing Brainrot Base Wars

The game is **already live** at https://www.roblox.com/games/79673833446434 (universe
`8420965215`, place `79673833446434`), name "Brainrot Base Wars", visibility **Public**.
This rebuild replaces the place's `.rbxl`; the ids in `PLAY.json` are the real published ones.

The experience description carries the play code:

```
makefun-ladder-dugout-vine
```

## Republish the rebuilt place

1. Build the place from `src/`:

   ```
   rojo build default.project.json --output game.rbxl
   ```

   `game.rbxl` must be a binary Roblox place (it is).

2. Republish the place with the **same universe/place** so the live URL and ids do not change.
   Use the Roblox **Open Cloud API** (Places API) with your `universe_id` `8420965215` and
   `place_id` `79673833446434`:

   ```
   PUT https://apis.roblox.com/universes/v1/universes/8420965215/places/79673833446434/version
   Content-Type: application/octet-stream
   x-api-key: <YOUR_OPEN_CLOUD_KEY>
   ```
   Body: the bytes of `game.rbxl`.

   (Alternatively, open `game.rbxl` in Roblox Studio and **Publish to Roblox** as a new version
   of the existing place, keeping the same place id.)

3. Keep the place **Public** (Creator Dashboard > Universe > the game > Set Public).

4. Keep the play code in the description. The description must contain the line
   `makefun-ladder-dugout-vine` (that is the `check --play-code 0` value the make.fun gate
   looks for). Do not remove it.

5. Upload the icon and first thumbnail = screenshot 1 (`screenshots/1-start.png`):
   Creator Dashboard > your game > Configure > Basic Info: set the Icon and the first thumbnail
   to that same 1280x720 image. This is the cover the make.fun dossier reads first.

> Note: the screenshots in `screenshots/` are composed isometric renders (Python + PIL), not
> Studio captures. That is fine for the make.fun entry; upload them as-is.