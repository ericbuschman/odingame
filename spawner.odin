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

	anim_idx := int(get_rand(0, f32(len(MONSTER_ANIMS))))
	new_enemy := enemy_new({555, 555}, anim_idx, name, .Keep_Away, 100, 2)
	append(
		&new_enemy.attacks,
		make_attack("PewPew", Projectile_Config{speed = 500, radius = 3}, 1, 1.5, 1),
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
		anim_idx := int(get_rand(0, f32(len(MONSTER_ANIMS))))
		new_enemy := enemy_new(
			{
				get_rand(
					max(f32(0), gd.player.loc.x - range_val),
					min(game.map_width - 64, gd.player.loc.x + range_val),
				),
				get_rand(
					max(f32(0), gd.player.loc.y - range_val),
					min(game.map_height - 64, gd.player.loc.y + range_val),
				),
			},
			anim_idx,
			name,
			.Towards_Player,
			100,
			2,
		)
		append(
			&new_enemy.attacks,
			make_attack("PewPew", Projectile_Config{speed = 500, radius = 3}, 1, 1.5, 1),
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
