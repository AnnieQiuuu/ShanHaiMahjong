# Architecture map

| Need to change | File or scene |
|---|---|
| Pet roster / image paths | `scripts/data/pet_catalog.gd` |
| Per-tile state | `scripts/model/mahjong_tile_state.gd` |
| Free/blocked rules and matching | `scripts/rules/board_rules.gd` |
| Solvable layout assignment | `scripts/generation/board_generator.gd` |
| Tile portrait, colors and overlays | `scenes/tile_view.tscn` / `scripts/views/tile_view.gd` |
| Spacing, hit-tests and tile creation | `scenes/board_view.tscn` / `scripts/views/board_view.gd` |
| Selection, hints, undo and win | `scripts/game/game_controller.gd` |
| Background, HUD and board position | `scenes/main.tscn` |

Data flow: `BoardGenerator` creates `MahjongTileState[]` -> `BoardView` instantiates reusable `TileView` nodes -> tap emits tile ID -> `GameController` checks `BoardRules` and mutates the model -> `BoardView.refresh()` updates display.

The view never removes matched tiles itself, and the pure rules never reference textures or UI.

Current limits: one 36-tile geometry; initial solvability only; no five-element skills, formal UI, collection or polished animation. Godot 4.3 headless import, 50 board seeds, core interactions and scene boot have been tested; visual QA remains.

