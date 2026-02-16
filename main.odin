package main

import "core:fmt"
import "core:math/rand"
import rl "vendor:raylib"

Game :: struct {
	game_data:  Game_Data,
	game_map:   Game_Map,
	map_width:  f32,
	map_height: f32,
	play_area:  rl.Rectangle,
	spawner:    Spawner,
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

	mw := f32(gm.width) * gm.tile_size
	mh := f32(gm.height) * gm.tile_size

	game := Game {
		game_data  = gd,
		game_map   = gm,
		map_width  = mw,
		map_height = mh,
		play_area  = {0, 0, mw, mh},
	}

	when !DEBUG_NO_ENEMIES {
		spawn_initial_enemy(&game.game_data, &game.spawner)
	}

	return game, true
}

game_deinit :: proc(game: ^Game) {
	game_map_deinit(&game.game_map)
	game_data_deinit(&game.game_data)
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
		min(gd.camera.target.x, game.map_width - gd.camera.offset.x),
	)
	gd.camera.target.y = max(
		gd.camera.offset.y,
		min(gd.camera.target.y, game.map_height - gd.camera.offset.y),
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

update_player :: proc(game: ^Game) {
	gd := &game.game_data
	mouse_world := rl.GetScreenToWorld2D(rl.GetMousePosition(), gd.camera)
	player_update(&gd.player, gd, game.game_map.obstructions[:], mouse_world, game.play_area)
}

update_enemies :: proc(game: ^Game) {
	gd := &game.game_data

	for &enemy in gd.enemies {
		enemy_update_attacks(&enemy, player_get_center(&gd.player), &gd.spawn_requests)
	}

	i := 0
	for i < len(gd.enemies) {
		enemy := &gd.enemies[i]
		if !is_in_bounds(enemy.loc, game.play_area) {enemy.active = false}

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

	// Move, trail, draw
	for &proj in gd.projectiles {
		projectile_move(&proj, gd.camera, game.play_area)

		if _, is_player := proj.parent.(^Player); is_player {
			particle_emit_trail(&gd.particles, proj.curloc, rl.GRAY)
		}
		projectile_draw(&proj)
	}

	resolve_projectile_collisions(gd, game.game_map.obstructions[:])
}

update_melee_attacks :: proc(game: ^Game) {
	gd := &game.game_data

	for &atk in gd.melee_attacks {
		melee_update(&atk)
		melee_draw(&atk)
	}

	resolve_melee_collisions(gd)
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
