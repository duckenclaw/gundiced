# CLAUDE.md

Godot 4.7 turn-based 2D hot-seat duel. Main scene: `src/ui/main_menu.tscn`. Rules in README.md.

## Commands

```bash
godot --headless --path . --import                         # refresh class cache after adding a class_name
godot --headless --path . --script tests/test_gundiced.gd  # rule tests (CI runs these)
```

## Architecture

- **One grid.** A cell is one 64 px tile (`Grid.CELL`). `Grid.to_world(cell)` is the cell centre. No physics: movement, shots and explosions are all resolved on the grid by `Board`.
- **Board owns the rules.** `Board` builds a level from its ASCII `layout` and answers every query: `is_floor`, `occupant_at` (crate / obstacle / living player, via the `occupant` group), `door_between`, `can_push`/`push`, `trace` (shot walk) and `explode`.
- **Doors are edges.** A `Door` is hinged on a grid corner and always lies on exactly one cell edge (`Door.edge()`); `Board.door_between(a, b)` finds the door on that edge and it blocks only that edge for movement, pushes and shots. Crossing it calls `pass_through`, which swings it a quarter turn around the hinge (state −90/0/+90); `can_pass` refuses a swing past ±90.
- **Damage is duck-typed.** Anything with `take_hit(dir: Vector2i)` can be shot. `dir` is the direction the damage travels; the shield blocks when `shield_dir == -dir`. `Vector2i.ZERO` means unblockable.
- **AP lives in Match.** Players emit `action_performed` after a successful action; failed actions never emit, so they cost nothing. New actions plug in by emitting it.
- **Kits:** `Health` (components_kit) on players, crates and doors; `AudioManager` / `SceneManager` (core) are reached at runtime through `Sfx.play` and `get_node("/root/…")`, so scripts also compile under `--script` test runs where autoload globals don't exist yet.
- **Turn log.** Players emit `moved` / `shot`; Match collects them and `Board.ghost` (`TurnGhost`) replays them at the next turn start. `end_turn_requested` passes early.
- **Art pipeline.** Sprites are pixel-snapped (`tools/pixelsnap.py`) and imported with mipmaps; the project default canvas filter is linear+mipmaps. Players have empty hands; `Player.hand_uv` places the held weapon. SFX come from `tools/synth_sfx.py` and play by name via `Sfx.named()`.
- **Code-built visuals.** Entities, HUD and dice build their nodes in `_ready`; scenes are thin (`match.tscn`, `main_menu.tscn`, `src/levels/*.tscn`).
