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
3. **Active turn**: spend AP on actions until it reaches 0.
4. **Hand-off**: control passes to the next player.

### Actions

| Action | AP | Notes |
|---|---|---|
| Move (1 cell) | 1 | Cardinal directions only. Failed moves cost nothing. |
| Push a crate | 1 | Walking into a crate pushes it (and any chain behind it) one cell. |
| Move through a door | 1 | The door swings 90° in the direction of motion. |
| Enter aim mode | 0 | Shows the shot line, the cell it hits and any blast area. |
| Change aim direction | 0 | Movement keys rotate the aim (or move the throw target). |
| Fire | 1 | Damage lands on the first thing in line. |
| Turn your shield | 0 | Only if you carry one. |
| Pick up | 0 | Step onto a pickup to take it. |

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
- **Doors**: 1 HP, sit on the edge between two cells, rotation limited to ±90° from
  closed. Each pass swings them 90°; a pass past the limit is refused. Closed doors
  block shots on their edge; open doors lie across their two cells and catch shots
  crossing them side-on.
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
|  door on this cell's LEFT edge     _  door on this cell's TOP edge
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

```bash
godot --headless --path . --import
godot --headless --path . --script tests/test_gundiced.gd
```

## Credits

Character, weapon and SFX art carried over from the original *dice-gunmen*
prototype. Tiles and props were generated with Higgsfield (GPT Image) using the
characters as a style reference.
