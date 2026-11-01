# AI coding instructions — 山海麻将

This is a Godot 4.3+ GDScript project. Make small, reviewable changes. Preserve approved hand-painted tile art and original pet PNGs.

## Module boundaries

- `scripts/model/`: `MahjongTileState` game state, no UI. Avoid native Godot class names.
- `scripts/rules/`: pure geometry/matching rules, no textures or input.
- `scripts/generation/`: solvable initial layout and pairs.
- `scripts/views/`: tile visuals, board presentation and hit-testing; no matching decisions.
- `scripts/game/`: selection, undo, hints, victory and input shortcuts.
- `scripts/data/`: pet IDs and resource paths.
- `scenes/`: editor-facing visual composition.
- `assets/`: user artwork; do not regenerate or overwrite without explicit approval.

## Invariants

1. MVP has one level per region: 28/36/44/52/60/68/80/92 tiles and up to 2/3/3/4/4/5/5/6 layers. Retain the original 36-tile layout as a regression fixture.
2. Levels use 5/7/8/9/10/11/12/14 species, at least one pair each at deal time, covering all five elements. Fire and wind remove single tiles; only lightning removes legal pairs. Odd remnants and player deadlocks are intentional. Shuffle preserves identities/counts and guarantees a legal pair when possible, not a complete solution.
3. A free tile has no upper tile overlapping its *playable face* (the jade-green
   right/bottom thickness is excluded), and at least one horizontal side
   unblocked by a remaining same-layer neighbor in the same row.
   Matching does not require tiles to be on the same layer.
4. Preserve `R` restart, `Z` undo, `H` hint shortcuts.
5. Initial decks are solvable, but arbitrary player paths may deadlock.
6. Report changed files, tests, and any unverified behavior.
7. Run Godot headless smoke tests when an executable is available.
8. Keep artistic values editor-adjustable; no display constants in game rules.

## Style

Warm ivory face, irregular orange hand-painted border, flat jade-green sides, brown contours and original pet silhouettes. Avoid glossy materials.

