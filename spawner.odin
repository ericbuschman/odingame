package main

import "core:fmt"
import rl "vendor:raylib"

Spawn_Request :: struct {
	parent: Entity,
	target: rl.Vector2,
	damage: i32,
	speed:  f32,
}

Spawner :: struct {
	enemy1_timer: f32,
	enemy2_timer: f32,
	enemy_id:     i32,
}

spawn_initial_enemy :: proc(gd: ^Game_Data, spawner: ^Spawner) {
	spawner.enemy_id += 1
	name_buf: [64]byte
	name := fmt.bprintf(name_buf[:], "Enemy%d", spawner.enemy_id)

	new_enemy := enemy_new({555, 555}, gd.enemy_tex, name, .Keep_Away, 100, 2)
	append(
		&new_enemy.attacks,
		make_attack("PewPew", Projectile_Config{speed = 500, radius = 3}, 1, 1.5),
	)
	append(&gd.enemies, new_enemy)
}

spawn_enemies :: proc(game: ^Game) {
	gd := &game.game_data
	spawner := &game.spawner
	spawner.enemy1_timer -= rl.GetFrameTime()

	if spawner.enemy1_timer <= 0 {
		spawner.enemy_id += 1
		name_buf: [64]byte
		name := fmt.bprintf(name_buf[:], "Enemy%d", spawner.enemy_id)

		range_val: f32 = 200 * f32(STEP_SIZE)
		new_enemy := enemy_new(
			{
				get_rand(
					max(f32(0), gd.player.loc.x - range_val),
					min(game.map_width - f32(gd.enemy_tex.width), gd.player.loc.x + range_val),
				),
				get_rand(
					max(f32(0), gd.player.loc.y - range_val),
					min(game.map_height - f32(gd.enemy_tex.height), gd.player.loc.y + range_val),
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
		spawner.enemy1_timer = get_rand(1, 2.5)
		// fmt.printf(
		// 	"Enemy%d spawned at (%.0f, %.0f)\n",
		// 	spawner.enemy_id,
		// 	new_enemy.loc.x,
		// 	new_enemy.loc.y,
		// )
		append(&gd.enemies, new_enemy)
	}
}
