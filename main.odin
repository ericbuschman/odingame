package main

import "core:fmt"
import "core:math/rand"
import rl "vendor:raylib"

Game :: struct {
	game_data:    Game_Data,
	game_map:     Game_Map,
	enemy1_timer: f32,
	enemy2_timer: f32,
	enemy_id:     i32,
}

get_rand :: proc(lo, hi: f32) -> f32 {
	return lo + rand.float32() * (hi - lo)
}

game_init :: proc() -> (Game, bool) {
	gd := game_data_init()

	gm, ok := game_map_init("resources/maps/rand2.json", 4.0)
	if !ok {
		game_data_deinit(&gd)
		return {}, false
	}

	map_width = f32(gm.width) * gm.tile_size
	map_height = f32(gm.height) * gm.tile_size
	play_area = {0, 0, map_width, map_height}

	game := Game {
		game_data    = gd,
		game_map     = gm,
		enemy1_timer = 0,
		enemy2_timer = 0,
		enemy_id     = 0,
	}

	when !DEBUG_NO_ENEMIES {
		spawn_initial_enemy(&game)
	}

	return game, true
}

game_deinit :: proc(game: ^Game) {
	game_map_deinit(&game.game_map)
	game_data_deinit(&game.game_data)
}

spawn_initial_enemy :: proc(game: ^Game) {
	game.enemy_id += 1
	name_buf: [64]byte
	name := fmt.bprintf(name_buf[:], "Enemy%d", game.enemy_id)

	new_enemy := enemy_new({555, 555}, game.game_data.enemy_tex, name, .Keep_Away, 100, 2)
	append(
		&new_enemy.attacks,
		make_attack("PewPew", Projectile_Config{speed = 500, radius = 3}, 1, 1.5),
	)
	append(&game.game_data.enemies, new_enemy)
}

game_restart :: proc(gd: ^Game_Data) {
	player_reset(&gd.player)
	for &e in gd.enemies {enemy_deinit(&e)}
	clear(&gd.enemies)
	clear(&gd.projectiles)
	clear(&gd.melee_attacks)
}

game_update :: proc(game: ^Game) {
	gd := &game.game_data

	// Camera follows player
	gd.camera.target = gd.player.loc
	gd.camera.target.x = max(
		gd.camera.offset.x,
		min(gd.camera.target.x, map_width - gd.camera.offset.x),
	)
	gd.camera.target.y = max(
		gd.camera.offset.y,
		min(gd.camera.target.y, map_height - gd.camera.offset.y),
	)

	rl.BeginDrawing()
	defer rl.EndDrawing()

	rl.ClearBackground(rl.BLACK)
	rl.BeginMode2D(gd.camera)
	defer rl.EndMode2D()

	game_map_draw(&game.game_map, gd.camera)

	// Game state
	gsr := process_game_state(gd.state, gd)
	gd.state = gsr.new_state
	gd.time_accumulator += f64(gsr.time_accumulator)
	if gsr.is_restart {game_restart(gd)}
	if gsr.skip_loop {return}

	when !DEBUG_NO_ENEMIES {
		spawn_enemies(game)
	}

	update_player(game)
	update_enemies(game)
	update_projectiles(game)
	update_melee_attacks(game)

	// Draw obstructions
	for b in game.game_map.obstructions {
		source := rl.Rectangle{0, 0, f32(gd.boulder_tex.width), f32(gd.boulder_tex.height)}
		rl.DrawTexturePro(gd.boulder_tex, source, b, {0, 0}, 0, rl.WHITE)
	}

	draw_hud(gd.heart_tex, gd.player.health, &gd.camera)
	player_draw(&gd.player)
	particle_system_update(&gd.particles)
	particle_system_draw(&gd.particles)
}

spawn_enemies :: proc(game: ^Game) {
	gd := &game.game_data
	game.enemy1_timer -= rl.GetFrameTime()

	if game.enemy1_timer <= 0 {
		game.enemy_id += 1
		name_buf: [64]byte
		name := fmt.bprintf(name_buf[:], "Enemy%d", game.enemy_id)

		range_val: f32 = 200 * f32(STEP_SIZE)
		new_enemy := enemy_new(
			{
				get_rand(
					max(f32(0), gd.player.loc.x - range_val),
					min(map_width - f32(gd.enemy_tex.width), gd.player.loc.x + range_val),
				),
				get_rand(
					max(f32(0), gd.player.loc.y - range_val),
					min(map_height - f32(gd.enemy_tex.height), gd.player.loc.y + range_val),
				),
			},
			gd.enemy_tex,
			name,
			.Towards_Player,
			100,
			2,
		)
		append(
			&new_enemy.attacks,
			make_attack("PewPew", Projectile_Config{speed = 500, radius = 3}, 1, 1.5),
		)
		game.enemy1_timer = get_rand(1, 2.5)
		fmt.printf(
			"Enemy%d spawned at (%.0f, %.0f)\n",
			game.enemy_id,
			new_enemy.loc.x,
			new_enemy.loc.y,
		)
		append(&gd.enemies, new_enemy)
	}
}

update_player :: proc(game: ^Game) {
	gd := &game.game_data
	mouse_world := rl.GetScreenToWorld2D(rl.GetMousePosition(), gd.camera)
	player_update(&gd.player, gd, game.game_map.obstructions[:], mouse_world)
}

update_enemies :: proc(game: ^Game) {
	gd := &game.game_data

	for &enemy in gd.enemies {
		enemy_update_attacks(&enemy, player_get_center(&gd.player), &gd.spawn_requests)
	}

	i := 0
	for i < len(gd.enemies) {
		enemy := &gd.enemies[i]
		if !is_in_bounds(enemy.loc) {enemy.active = false}

		if enemy.active {
			enemy_movement(enemy, &gd.player, game.game_map.obstructions[:])
			enemy_draw(enemy)
			i += 1
		} else {
			gd.player.score += 1
			if gd.player.score % 2 == 0 {
				gd.state = .Level_Up
			}
			enemy_deinit(enemy)
			unordered_remove(&gd.enemies, i)
			fmt.printf("Enemy removed, array count: %d\n", len(gd.enemies))
		}
	}
}

update_projectiles :: proc(game: ^Game) {
	gd := &game.game_data

	// Handle spawn requests
	for spawn in gd.spawn_requests {
		append(
			&gd.projectiles,
			projectile_new(spawn.parent, spawn.target, spawn.damage, spawn.speed),
		)
	}
	clear(&gd.spawn_requests)

	// Projectile lifecycle
	i := 0
	for i < len(gd.projectiles) {
		proj := &gd.projectiles[i]

		switch p in proj.parent {
		case ^Player:
			particle_emit_trail(&gd.particles, proj.curloc, rl.GRAY)
		case ^Enemy:
		}
		projectile_draw(proj, gd.camera)

		// Obstruction collisions
		for b in game.game_map.obstructions {
			if rl.CheckCollisionCircleRec(proj.curloc, proj.radius, b) {
				proj.active = false
				particle_emit_collision(&gd.particles, proj.curloc, rl.GRAY)
				break
			}
		}

		// Enemy collisions
		for &enemy in gd.enemies {
			if projectile_check_collision(proj, &enemy) {
				_, is_player := proj.parent.(^Player)
				if is_player {
					particle_emit_collision(&gd.particles, proj.curloc, rl.ORANGE)
					enemy_take_damage(&enemy, proj.damage)
					proj.active = false
				}
			}
		}

		// Player collision
		if projectile_check_collision(proj, &gd.player) {
			player_take_damage(&gd.player, proj.damage)
			if gd.player.health <= 0 {
				gd.state = .Game_Over
			} else {
				particle_emit_collision(&gd.particles, proj.curloc, rl.RED)
			}
			proj.active = false
		}

		if !proj.active {
			unordered_remove(&gd.projectiles, i)
		} else {
			i += 1
		}
	}
}

update_melee_attacks :: proc(game: ^Game) {
	gd := &game.game_data

	i := 0
	for i < len(gd.melee_attacks) {
		atk := &gd.melee_attacks[i]
		melee_draw(atk)

		// Enemy collisions (player-owned melee)
		for &en in gd.enemies {
			if melee_check_collision(atk, &en) {
				_, is_player := atk.parent.(^Player)
				if is_player {
					en_center := enemy_get_center(&en)
					particle_emit_collision(&gd.particles, en_center, rl.GREEN)
					enemy_take_damage(&en, atk.damage)
				}
			}
		}

		// Player collision (enemy-owned melee)
		if melee_check_collision(atk, &gd.player) {
			_, is_enemy := atk.parent.(^Enemy)
			if is_enemy {
				player_take_damage(&gd.player, atk.damage)
				if gd.player.health <= 0 {
					gd.state = .Game_Over
				} else {
					p_center := player_get_center(&gd.player)
					particle_emit_collision(&gd.particles, p_center, rl.RED)
				}
			}
		}

		if !atk.active {
			unordered_remove(&gd.melee_attacks, i)
		} else {
			i += 1
		}
	}
}

main :: proc() {
	rl.InitWindow(SCREEN_WIDTH, SCREEN_HEIGHT, "OdinGame")
	defer rl.CloseWindow()
	rl.SetTargetFPS(60)
	rl.SetExitKey(.KEY_NULL)

	game, ok := game_init()
	if !ok {
		fmt.eprintln("Failed to initialize game")
		return
	}
	defer game_deinit(&game)

	for !rl.WindowShouldClose() && game.game_data.state != .Quit {
		game_update(&game)
	}
}
