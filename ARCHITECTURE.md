# OdinGame Architecture

A top-down 2D shooter built with Odin and Raylib. The player fights waves of enemies using melee and projectile attacks, with a level-up upgrade system.

## Project Structure

```
odingame/
  ai.odin            # Movement AI utilities (move_towards, move_away)
  app.odin           # Application state, settings persistence
  attack.odin        # Attack configuration (melee/projectile), cooldowns
  collision.odin     # Collision resolution for projectiles and melee
  constants.odin     # Screen dimensions, debug flags
  entity.odin        # Shared Entity union (Player | Enemy) and helpers
  enemy.odin         # Enemy struct, AI behavior, attacks
  game_data.odin     # Central game state container, textures, arrays
  game_map.odin      # Tile map loading from JSON, rendering
  hud.odin           # Health hearts display
  main.odin          # Game loop, initialization, orchestration
  melee.odin         # Melee attack geometry, animation, collision
  menu.odin          # Centralized menu engine (main menu, pause, game over, level up, settings)
  particle.odin      # Particle system for visual effects
  player.odin        # Player struct, movement, input, attacks
  projectile.odin    # Projectile movement, drawing, collision
  save.odin          # Save/load game state via JSON
  spawner.odin       # Enemy spawning timers and logic
  sprites.odin       # Sprite loading from resources/
  state.odin         # Game state machine (Playing, Paused, Level_Up, etc.)
  text.odin          # Text rendering utilities (word wrap)
  resources/
    maps/             # JSON tile maps (rand2.json)
    sprites/          # PNG sprite files (sprite_player.png, sprite_enemy.png, ...)
  saves/
    save.json         # Auto-generated player save file
  settings.json       # Persisted app settings (volume, fullscreen)
```

## Core Data Flow

```
main()
  -> App state machine (App_State: Main_Menu | Settings | Playing | Quitting)
       Main_Menu / Settings:
         main_menu_update() / settings_menu_update()
       Playing:
         game_init()           # Load map, textures, create player
         game_update() loop    # Runs each frame:
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

### Application Layer

| File | Purpose | Key Types/Procs |
|------|---------|-----------------|
| **main.odin** | Entry point and game loop orchestration. | `Game`, `game_init`, `game_update`, `game_restart`, `get_rand` |
| **app.odin** | Top-level application state machine. Manages main menu vs playing vs settings transitions; loads/saves/applies settings. | `App_State` enum, `App_Settings`, `App`, `Settings_Json`, `settings_load`, `settings_save`, `settings_apply` |

### Game State & Data

| File | Purpose | Key Types/Procs |
|------|---------|-----------------|
| **state.odin** | In-game state machine with transitions. Handles pause, game over, level-up trigger. | `Game_State` enum, `Game_State_Result`, `process_game_state` |
| **game_data.odin** | Central container for all runtime game state: textures, player, enemy/projectile/melee arrays, camera, particles, spawn requests, menu nav. | `Game_Data`, `game_data_init`, `is_on_screen`, `is_in_bounds` |
| **constants.odin** | Compile-time constants for screen size (1024x768), tile step, debug flags. | `SCREEN_WIDTH`, `SCREEN_HEIGHT`, `SHOW_DEBUG`, `DEBUG_NO_ENEMIES` |

### Entities

| File | Purpose | Key Types/Procs |
|------|---------|-----------------|
| **entity.odin** | Shared `Entity` union type used by projectiles, melee, and spawners to reference either a Player or Enemy. | `Entity`, `entity_get_area`, `entity_get_center`, `entity_same` |
| **player.odin** | Player input (WASD/arrows), velocity-based movement with acceleration/friction, dodge/dash, attack firing with upgrade modifiers. | `Player`, `Move_Dir`, `player_init`, `player_reset`, `player_apply_defaults`, `player_take_damage`, `player_dash`, `player_movement`, `player_draw`, `player_update` |
| **enemy.odin** | Enemy AI with personality-driven behavior. Supports `Towards_Player`, `Keep_Away`, and `Run_Away` states. Axis-aligned obstacle collision. | `Enemy`, `Enemy_State`, `enemy_new`, `enemy_movement`, `enemy_update_attacks`, `enemy_draw` |

### Combat

| File | Purpose | Key Types/Procs |
|------|---------|-----------------|
| **attack.odin** | Attack definitions supporting both melee and projectile types. Cooldown timer system. | `Attack`, `Attack_Type` (union), `Melee_Config`, `Projectile_Config`, `make_attack`, `attack_tick` |
| **projectile.odin** | Projectile creation, movement, drawing (with optional glow), and collision testing against entities. | `Projectile`, `projectile_new`, `projectile_move`, `projectile_draw`, `projectile_check_collision`, `get_projectile_start_point` |
| **melee.odin** | Melee attacks with Sweep (arc) and Thrust (stab) styles. Line-based collision with point-stepping. Animated glow effect. | `Melee_Attack`, `Attack_Style`, `melee_new_with_params`, `melee_check_collision`, `melee_update`, `melee_draw` |
| **collision.odin** | Collision resolution loops. Handles projectile-vs-obstacle/enemy/player and melee-vs-enemy/player, including particle emission and damage application. | `resolve_projectile_collisions`, `resolve_melee_collisions` |
| **spawner.odin** | Enemy spawning system. Timer-based waves that spawn enemies near the player with randomized positions. | `Spawner`, `Spawn_Request`, `spawn_enemies`, `spawn_initial_enemy` |

### World

| File | Purpose | Key Types/Procs |
|------|---------|-----------------|
| **game_map.odin** | Loads tile maps from JSON files. Renders only visible tiles (frustum culling). Caches textures by type name. | `Game_Map`, `Tile`, `game_map_init`, `game_map_draw`, `game_map_get_texture` |
| **ai.odin** | Simple movement utilities used by enemy AI. | `move_towards`, `move_away` |

### Rendering & UI

| File | Purpose | Key Types/Procs |
|------|---------|-----------------|
| **particle.odin** | Particle system for collision bursts and projectile trails. Gravity, alpha fade, automatic cleanup. | `Particle_System`, `Particle`, `particle_emit_collision`, `particle_emit_trail`, `particle_system_update`, `particle_system_draw` |
| **hud.odin** | Health hearts display. | `draw_hud` |
| **menu.odin** | Generalized menu engine powering all UI screens. Supports vertical/horizontal grid layouts, keyboard and mouse navigation, hotkeys, card and button styles, glow effects. | `Menu_Item_Style`, `Menu_Button`, `Menu_Layout`, `Menu_Def`, `Menu_Nav`, `BUTTON_STYLE`, `CARD_STYLE`, `draw_menu`, `draw_pause_menu`, `draw_game_over_menu`, `draw_level_up_menu`, `main_menu_update`, `settings_menu_update` |
| **text.odin** | Text rendering utility with automatic word wrapping. | `word_wrap` |
| **sprites.odin** | Loads PNG sprites from `resources/sprites/` with fallback for variant names. | `load_sprite` |

### Persistence

| File | Purpose | Key Types/Procs |
|------|---------|-----------------|
| **save.odin** | Serializes and restores game state via JSON. Manages save file lifecycle. | `Save_File`, `Player_Save`, `Enemy_Save`, `Spawner_Save`, `save_game`, `save_load`, `save_exists`, `save_delete` |

## Key Patterns

**App State vs Game State** -- Two distinct state machines. `App_State` (in `app.odin`) controls top-level navigation: `Main_Menu`, `Settings`, `Playing`, `Quitting`. `Game_State` (in `state.odin`) controls in-game states: `Playing`, `Paused`, `Level_Up`, `Game_Over`, `Quit`.

**Entity Union** -- `Entity` is a union of `^Player | ^Enemy`. Projectiles and melee attacks store their parent as an `Entity`, and `entity_same` prevents self-hits during collision checks.

**Centralized Menu Engine** -- All menus (main, pause, game over, level up, settings) are driven by `draw_menu` in `menu.odin` via `Menu_Def` descriptors. This keeps all menu rendering and input logic in one place.

**Update/Draw Separation** -- Movement and state updates happen before drawing. `projectile_move` and `melee_update` are called explicitly before their draw counterparts.

**Cooldown-Based Attacks** -- Each `Attack` has an `interval` and `remaining_interval`. `attack_tick` decrements the timer each frame and returns `true` when the attack is ready to fire, then resets.

**Spawn Request Queue** -- Enemies don't create projectiles directly. They push `Spawn_Request` structs onto `game_data.spawn_requests`, which `update_projectiles` processes into actual `Projectile` instances.

**Axis-Aligned Collision** -- Player and enemy movement test X and Y axes independently against obstacles, allowing sliding along walls.

**Map Bounds** -- `map_width`, `map_height`, and `play_area` live on the `Game` struct (not globals) and are passed explicitly to procs that need boundary checks.

**JSON Persistence** -- Both settings (`settings.json`) and save data (`saves/save.json`) are serialized via Odin's `encoding/json`. `App_Settings` is loaded at startup; save files capture player stats, enemy states, and spawner state.

## Adding New Features

**New enemy type** -- Add a new `Enemy_State` variant in `enemy.odin`, handle it in `enemy_movement`, and configure it in `spawner.odin`.

**New attack** -- Define a new `Melee_Config` or `Projectile_Config` in `attack.odin` and `append` it to a player or enemy's `attacks` array.

**New upgrade** -- Add a variant to `Attack_Upgrade` in `attack.odin`, add a button to `draw_level_up_menu` in `menu.odin`, and apply the effect in `player_update` in `player.odin`.

**New particle effect** -- Add a `particle_emit_*` proc in `particle.odin` and call it from the appropriate system.

**New game state** -- Add a variant to `Game_State` in `state.odin` and handle it in `process_game_state`.

**New menu screen** -- Define a `Menu_Def` with buttons and call `draw_menu` in `menu.odin`. Add a corresponding `App_State` or `Game_State` variant to trigger it.

**New save data** -- Extend the relevant `*_Save` struct in `save.odin` and update `save_game` / `save_load` accordingly.
