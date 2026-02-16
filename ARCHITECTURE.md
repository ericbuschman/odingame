# OdinGame Architecture

A top-down 2D shooter built with Odin and Raylib. The player fights waves of enemies using melee and projectile attacks, with a level-up upgrade system.

## Project Structure

```
odingame/
  main.odin          # Game loop, initialization, orchestration
  entity.odin        # Shared Entity union (Player | Enemy) and helpers
  player.odin        # Player struct, movement, input, attacks
  enemy.odin         # Enemy struct, AI behavior, attacks
  attack.odin        # Attack configuration (melee/projectile), cooldowns
  melee.odin         # Melee attack geometry, animation, collision
  projectile.odin    # Projectile movement, drawing, collision
  collision.odin     # Collision resolution for projectiles and melee
  spawner.odin       # Enemy spawning timers and logic
  particle.odin      # Particle system for visual effects
  game_data.odin     # Central game state container, textures, arrays
  game_map.odin      # Tile map loading from JSON, rendering
  state.odin         # Game state machine (Playing, Paused, Level_Up, etc.)
  hud.odin           # Health display, level-up card UI
  text.odin          # Centered text rendering with word wrap
  ai.odin            # Movement AI utilities (move_towards, move_away)
  sprites.odin       # Sprite loading from resources/
  constants.odin     # Screen dimensions, debug flags
  resources/
    sprites/          # PNG sprite files (sprite_player.png, sprite_enemy.png, ...)
    maps/             # JSON tile maps (rand2.json)
```

## Core Data Flow

```
main()
  -> game_init()         # Load map, textures, create player
  -> game_update() loop  # Runs each frame:
       1. Camera follows player
       2. process_game_state()    # Handle pause, game over, level up
       3. spawn_enemies()         # Timer-based enemy creation
       4. update_player()         # Input, movement, fire attacks
       5. update_enemies()        # AI movement, fire attacks
       6. update_projectiles()    # Move, draw, resolve collisions
       7. update_melee_attacks()  # Animate, resolve collisions
       8. Draw obstructions, HUD, player, particles
```

## File Guide

### Game Loop & State

| File | Purpose | Key Types/Procs |
|------|---------|-----------------|
| **main.odin** | Entry point and game loop orchestration. Ties all systems together. | `Game`, `game_init`, `game_update`, `game_restart` |
| **state.odin** | Game state machine with transitions. Handles pause screen, game over screen, level-up trigger. | `Game_State` enum, `process_game_state` |
| **game_data.odin** | Central container for all runtime game state: textures, player, enemy/projectile/melee arrays, camera, particles. | `Game_Data`, `game_data_init`, `is_on_screen`, `is_in_bounds` |
| **constants.odin** | Compile-time constants for screen size, tile step, debug flags. | `SCREEN_WIDTH`, `SCREEN_HEIGHT`, `SHOW_DEBUG`, `DEBUG_NO_ENEMIES` |

### Entities

| File | Purpose | Key Types/Procs |
|------|---------|-----------------|
| **entity.odin** | Shared `Entity` union type used by projectiles, melee, and spawners to reference either a Player or Enemy. | `Entity`, `entity_get_area`, `entity_get_center`, `entity_same` |
| **player.odin** | Player input (WASD/arrows), velocity-based movement with acceleration/friction, dodge/dash, attack firing with upgrade modifiers. | `Player`, `player_update`, `player_movement`, `player_dash` |
| **enemy.odin** | Enemy AI with personality-driven behavior. Supports Towards_Player, Keep_Away, and Run_Away states. Axis-aligned obstacle collision. | `Enemy`, `Enemy_State`, `enemy_movement`, `enemy_update_attacks` |

### Combat

| File | Purpose | Key Types/Procs |
|------|---------|-----------------|
| **attack.odin** | Attack definitions supporting both melee and projectile types. Cooldown timer system. | `Attack`, `Attack_Type` (union), `Melee_Config`, `Projectile_Config`, `attack_tick` |
| **projectile.odin** | Projectile creation, movement, drawing (with optional glow), and collision testing against entities. | `Projectile`, `projectile_new`, `projectile_move`, `projectile_draw`, `projectile_check_collision` |
| **melee.odin** | Melee attacks with Sweep (arc) and Thrust (stab) styles. Line-based collision with point-stepping. Animated glow effect. | `Melee_Attack`, `Attack_Style`, `melee_new_with_params`, `melee_check_collision`, `melee_draw` |
| **collision.odin** | Collision resolution loops extracted from main. Handles projectile-vs-obstacle/enemy/player and melee-vs-enemy/player, including particle emission and damage application. | `resolve_projectile_collisions`, `resolve_melee_collisions` |
| **spawner.odin** | Enemy spawning system. Timer-based waves that spawn enemies near the player with randomized positions. | `Spawner`, `Spawn_Request`, `spawn_enemies`, `spawn_initial_enemy` |

### World

| File | Purpose | Key Types/Procs |
|------|---------|-----------------|
| **game_map.odin** | Loads tile maps from JSON files. Renders only visible tiles (frustum culling). Caches textures by type name. | `Game_Map`, `Tile`, `game_map_init`, `game_map_draw` |
| **ai.odin** | Simple movement utilities used by enemy AI. | `move_towards`, `move_away` |

### Rendering & UI

| File | Purpose | Key Types/Procs |
|------|---------|-----------------|
| **particle.odin** | Particle system for collision bursts and projectile trails. Gravity, alpha fade, automatic cleanup. | `Particle_System`, `particle_emit_collision`, `particle_emit_trail` |
| **hud.odin** | Health hearts display and level-up card selection UI with hover glow. Cards use generic word wrapping. | `draw_hud`, `draw_level_up`, `draw_card` |
| **text.odin** | Centered text rendering with automatic word wrapping and bordered panel backgrounds. | `print_centered_text`, `word_wrap`, `draw_border` |
| **sprites.odin** | Loads PNG sprites from `resources/sprites/` with fallback for variant names. | `load_sprite` |

## Key Patterns

**Entity Union** -- `Entity` is a union of `^Player | ^Enemy`. Projectiles and melee attacks store their parent as an `Entity`, and `entity_same` prevents self-hits during collision checks.

**Update/Draw Separation** -- Movement and state updates happen before drawing. `projectile_move` and `melee_update` are called explicitly before their draw counterparts.

**Cooldown-Based Attacks** -- Each `Attack` has an `interval` and `remaining_interval`. `attack_tick` decrements the timer each frame and returns `true` when the attack is ready to fire, then resets.

**Spawn Request Queue** -- Enemies don't create projectiles directly. They push `Spawn_Request` structs onto `game_data.spawn_requests`, which `update_projectiles` processes into actual `Projectile` instances.

**Axis-Aligned Collision** -- Player and enemy movement test X and Y axes independently against obstacles, allowing sliding along walls.

**Map Bounds** -- `map_width`, `map_height`, and `play_area` live on the `Game` struct (not globals) and are passed explicitly to procs that need boundary checks.

## Adding New Features

**New enemy type** -- Add a new `Enemy_State` variant in `enemy.odin`, handle it in `enemy_movement`, and configure it in `spawner.odin`.

**New attack** -- Define a new `Melee_Config` or `Projectile_Config` in `attack.odin` and `append` it to a player or enemy's `attacks` array.

**New upgrade** -- Add a variant to `Attack_Upgrade` in `attack.odin`, add a card in `draw_level_up` in `hud.odin`, and apply the effect in `player_update` in `player.odin`.

**New particle effect** -- Add a `particle_emit_*` proc in `particle.odin` and call it from the appropriate system.

**New game state** -- Add a variant to `Game_State` in `state.odin` and handle it in `process_game_state`.
