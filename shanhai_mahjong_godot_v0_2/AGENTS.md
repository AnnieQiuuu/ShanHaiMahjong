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

1. 36 tiles arranged as 24 + 8 + 4 on three layers.
2. Nine species per deal, four copies each.
3. A free tile has no overlapping upper tile, and at least one horizontal side unblocked.
4. Preserve `R` restart, `Z` undo, `H` hint shortcuts.
5. Initial decks are solvable, but arbitrary player paths may deadlock.
6. Report changed files, tests, and any unverified behavior.
7. Run Godot headless smoke tests when an executable is available.
8. Keep artistic values editor-adjustable; no display constants in game rules.

## Style

Warm ivory face, irregular orange hand-painted border, flat jade-green sides, brown contours and original pet silhouettes. Avoid glossy materials.

