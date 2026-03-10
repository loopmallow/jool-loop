# Packs

Packs add candy types and can adjust game rules. They are **separate from the game binary** — drop them in at deploy time or ship them as DLC without recompiling.

## Structure

```
packs/
  default/               ← always loaded first; ships with the game
    pack.hscript
    shapes/
      blue_body_circle.png
      ...
  example/               ← a starter template for new packs
    pack.hscript
  mymypack/              ← your pack
    pack.hscript
    shapes/
      star_red.png
      star_blue.png
```

## Writing a pack

Create `pack.hscript` in your pack folder. Image paths are relative to that folder:

```haxe
pack.name = "Space Pack";
pack.matchScore = 15;          // points per candy cleared (default: 10)
pack.addCandy("shapes/star_red.png");
pack.addCandy("shapes/star_blue.png");
```

No Haxe toolchain required. The script runs inside the game at startup.

Available globals: `pack` (PackApi), `Math`, `Std`, `trace`.

## Deploying

**Web** — run `make web`. All `packs/*/` folders are copied to `dist/web/packs/`
and a `manifest.txt` is generated automatically. Serve them alongside `game.js`.

**Desktop (HashLink)** — copy the `packs/` folder next to the `.hl` file and the
`hl` runtime. `LocalFileSystem` reads it directly at startup.

To **ship a different default** (e.g. a themed version of the app), just replace
`packs/default/` with your own assets — no code changes needed.

## Load order

1. `default` — always first
2. All other pack folders, alphabetically

Each pack's candies are appended in order. `matchScore` is taken from the last
loaded pack that sets it.
