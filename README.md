# Gundiced

A turn-based, hot-seat grid duel for **Godot 4**. Two robot gunslingers face off;
a D6 roll each turn decides how many actions you get. Walls, pushable crates and
swinging doors make every turn a small puzzle.

Built on the shared **[godot-game-kit](https://github.com/duckenclaw/godot-game-kit)**
addons (`core`, `settings_kit`, `components_kit`), starting from the
[top-down template](https://github.com/duckenclaw/topdown-godot-template) with all of
its 3D world stripped out: this is a pure 2D game.

## Install

The kits under `addons/` are git submodules:

```bash
git clone --recurse-submodules https://github.com/duckenclaw/gundiced
```

Open in Godot 4.7+ and press F5.

## Game rules

### Setup
- 2 players spawn at opposite ends of the level.
- Each player has 1 HP. One clean hit ends the duel.
- A contested D6 roll decides who acts first (re-rolled on a tie).

### Turn structure
1. **Roll**: the active player rolls a D6 for that many Action Points (AP). The
   die is drawn in the player's colour.
2. **Intermission**: a "PLAYER N TURN" banner, then the die flies into your AP bar.
3. **Active turn**: spend AP on actions until it reaches 0, or press **Enter** to
   pass early. While you aim, the AP pip the shot will spend blinks.
4. **Hand-off**: control passes to the next player. While they roll, the board
   replays your turn in your colour: footprints along your path and your shot lines.

### Actions

| Action | AP | Notes |
|---|---|---|
| Move (1 cell) | 1 | Cardinal directions only. Failed moves cost nothing. |
| Push a crate | 1 | Walking into a crate pushes it (and any chain behind it) one cell. |
| Push a door | 1 | Walking across the edge a door lies on swings it 90° around its hinge. |
| Enter aim mode | 0 | Shows the shot line, the cell it hits and any blast area. |
| Change aim direction | 0 | Movement keys rotate the aim (or move the throw target). |
| Fire | 1 | Damage lands on the first thing in line. |
| Turn your shield | 0 | Only if you carry one. |
| Pick up | 0 | Step onto a pickup to take it. |
| End turn | 0 | Forfeit the AP you have left. |

### Weapons

Everyone starts with an endless **revolver**. Pickups swap in a special weapon with
limited ammo; when it runs dry you fall back to the revolver.

| Weapon | Ammo | Effect |
|---|---|---|
| Revolver | ∞ | First thing in line takes 1 damage. |
| Sniper | 2 | Pierces crates and doors (damaging them) until it hits a player or wall. |
| RPG | 1 | Explodes in a `+` where it hits. The splash can catch you too. |
| Molotov | 1 | Thrown. Sets a `+` on fire; standing in it or walking in kills. Burns out at the start of your next turn. |
| Grenade | 1 | Thrown. Explodes in a `+` at the start of your next turn. |
| **Shield** | 1 save | Directional. Absorbs one shot or explosion coming from the side it faces, then breaks. Fire and a grenade on your own cell can't be blocked. Press **Q** to turn it (free). |

### Terrain
- **Floor**: the only cells you can stand on.
- **Walls** and **decor** (barrels, cacti, rocks, hay, troughs): block movement
  and shots. Indestructible.
- **Crates**: 1 HP cover that blocks shots and can be pushed in chains. A push fails
  (and you stay put) if the back of the chain hits a wall, decor, a player, a door
  or the edge of the floor.
- **Doors**: 1 HP, one cell long, hinged on a grid corner. A door always lies on
  exactly one cell edge and blocks only that edge, for movement and for shots.
  Closed, it sits between its two cells. Walking across it pushes it a quarter turn
  around the hinge in the direction you walk, so it ends up lying on the hinge-side
  edge of the cell you entered and the doorway is clear. Pushing it again from
  the far side swings it back closed; a push that would take it past ±90° from
  closed is refused (and costs nothing). Crates can't be pushed through a door.
- **Plates**: end your turn on a gold `+` plate for +2 AP next turn, or on a red `−`
  plate to drain 1 AP from the next player.

### Win condition
Last gunslinger standing wins.

## Controls

| Key | Action |
|---|---|
| `W` / `↑`, `S` / `↓`, `A` / `←`, `D` / `→` | Move / aim |
| `Space` / `Z` | Shoot (enter aim, then fire) |
| `Q` / `X` | Turn shield |
| `E` / `Backspace` | Cancel aim |
| `Enter` / `F` | End turn |
| `R` | Rematch (after a win) |
| `Esc` | Back to menu |

All bindings live in the Input Map and are exposed to the Settings Kit's rebind UI.

## Making levels

A level is a scene whose root uses [`src/board/board.gd`](src/board/board.gd). Paint
it with the `layout` text field (it previews live in the editor):

```
#  wall        .  plank floor   ,  sand floor   (space) void
1 2  spawns    B  crate         b barrel  c cactus  r rock  h hay  t trough
+  bonus plate   -  drain plate
S sniper  R rpg  M molotov  G grenade  D shield
|  door on this cell's LEFT edge, hinged at the top    !  same, hinged at the bottom
_  door on this cell's TOP edge, hinged at the left    ~  same, hinged at the right
```

Then add it to `Match.LEVELS` in [`src/match/match.gd`](src/match/match.gd).

## Project layout

- `src/board/`: `Board` (level builder plus all grid rules), `Grid`, `AimOverlay`.
- `src/entities/`: `Player`, `Crate`, `Door`, `Obstacle`, `Pickup`, `SpecialCell`,
  `Hazard`, the `Weapons` table.
- `src/match/`: the turn loop, AP and camera.
- `src/ui/`: main menu, HUD and the dice roll animation.
- `src/fx/`: projectiles, particles, popups, screen shake, SFX routing.
- `tests/test_gundiced.gd`: headless rule tests, run in CI.
- `tools/synth_sfx.py`: regenerates the synthesized sound effects (`python3 tools/synth_sfx.py`).
- `tools/pixelsnap.py`: snaps soft or AI-made pixel art onto its true pixel grid
  (`python3 tools/pixelsnap.py in.png out.png [--key] [--scale 2]`).

```bash
godot --headless --path . --import
godot --headless --path . --script tests/test_gundiced.gd
```

## Credits

Character, weapon art and the step/shot/pickup sounds come from the original
*dice-gunmen* prototype. The characters were edited with Higgsfield (GPT Image) to
empty their hands so the held weapon is drawn separately. Tiles and props were
generated with Higgsfield using the characters as a style reference, and all
sprites were snapped to their pixel grid with `tools/pixelsnap.py`. The other sound
effects are synthesized by `tools/synth_sfx.py`.
