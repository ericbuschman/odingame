package main

import rl "vendor:raylib"

Game_Data :: struct {
	time_accumulator: f64,
	particles:        Particle_System,
	boulder_tex:      rl.Texture2D,
	heart_tex:        rl.Texture2D,
	player_tex:       rl.Texture2D,
	enemy_tex:        rl.Texture2D,
	player:           Player,
	enemies:          [dynamic]Enemy,
	projectiles:      [dynamic]Projectile,
	melee_attacks:    [dynamic]Melee_Attack,
	camera:           rl.Camera2D,
	state:            Game_State,
	spawn_requests:   [dynamic]Spawn_Request,
}

game_data_init :: proc() -> Game_Data {
	boulder_tex := load_sprite("boulder")
	heart_tex   := load_sprite("heart")
	player_tex  := load_sprite("player")
	enemy_tex   := load_sprite("enemy")
	p           := player_init(player_tex)

	return Game_Data {
		time_accumulator = 0,
		particles        = particle_system_init(),
		boulder_tex      = boulder_tex,
		heart_tex        = heart_tex,
		player_tex       = player_tex,
		enemy_tex        = enemy_tex,
		player           = p,
		enemies          = make([dynamic]Enemy, 0, 100),
		projectiles      = make([dynamic]Projectile, 0, 100),
		melee_attacks    = make([dynamic]Melee_Attack, 0, 20),
		camera           = rl.Camera2D {
			offset   = {f32(SCREEN_WIDTH) / 2, f32(SCREEN_HEIGHT) / 2},
			target   = p.loc,
			rotation = 0,
			zoom     = 1.0,
		},
		state            = .Playing,
		spawn_requests   = make([dynamic]Spawn_Request, 0, 100),
	}
}

game_data_deinit :: proc(gd: ^Game_Data) {
	particle_system_deinit(&gd.particles)
	rl.UnloadTexture(gd.boulder_tex)
	rl.UnloadTexture(gd.heart_tex)
	rl.UnloadTexture(gd.player_tex)
	rl.UnloadTexture(gd.enemy_tex)
	player_deinit(&gd.player)
	delete(gd.enemies)
	delete(gd.projectiles)
	delete(gd.melee_attacks)
	delete(gd.spawn_requests)
}

is_on_screen :: proc(pos: rl.Vector2, camera: rl.Camera2D) -> bool {
	screen_pos := rl.GetWorldToScreen2D(pos, camera)
	return screen_pos.x >= 0 && screen_pos.x < f32(rl.GetScreenWidth()) &&
	       screen_pos.y >= 0 && screen_pos.y < f32(rl.GetScreenHeight())
}

is_in_bounds :: proc(pos: rl.Vector2) -> bool {
	return pos.x > 0 && pos.x < map_width &&
	       pos.y > 0 && pos.y < map_height
}
