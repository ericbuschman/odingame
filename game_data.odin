package main

import "core:fmt"
import "core:math/rand"
import rl "vendor:raylib"

Level_Up_Option :: struct {
	attack_idx:   int,
	upgrade_type: Upgrade_Type,
}

Game_Data :: struct {
	time_accumulator: f64,
	particles:        Particle_System,
	boulder_tex:      rl.Texture2D,
	heart_tex:        rl.Texture2D,
	atlas:            Sprite_Atlas,
	weapons_tex:      [dynamic]rl.Texture2D,
	player:           Player,
	enemies:          [dynamic]Enemy,
	projectiles:      [dynamic]Projectile,
	melee_attacks:    [dynamic]Melee_Attack,
	camera:           rl.Camera2D,
	state:            Game_State,
	spawn_requests:   [dynamic]Spawn_Request,
	menu_nav:         Menu_Nav,
	attack_nav:       Menu_Nav,
	level_up_options: [3]Level_Up_Option,
	level_up_count:   int,
}

game_data_init :: proc() -> Game_Data {
	boulder_tex := load_sprite("boulder")
	heart_tex := load_sprite("heart")
	player_tex := load_sprite("player")
	p := player_init(player_tex)

	atlas, atlas_ok := load_atlas("resources/sprites/atlas.json")
	if !atlas_ok {
		fmt.eprintln("Failed to load sprite atlas")
	}

	weapons_tex := make([dynamic]rl.Texture2D, 0, 2)
	append(&weapons_tex, load_sprite("sword", 0.5))
	append(&weapons_tex, load_sprite("bow", 0.5))

	return Game_Data {
		time_accumulator = 0,
		particles = particle_system_init(),
		boulder_tex = boulder_tex,
		heart_tex = heart_tex,
		atlas = atlas,
		weapons_tex = weapons_tex,
		player = p,
		enemies = make([dynamic]Enemy, 0, 100),
		projectiles = make([dynamic]Projectile, 0, 100),
		melee_attacks = make([dynamic]Melee_Attack, 0, 20),
		camera = rl.Camera2D {
			offset = {f32(SCREEN_WIDTH) / 2, f32(SCREEN_HEIGHT) / 2},
			target = p.loc,
			rotation = 0,
			zoom = 1.0,
		},
		state = .Playing,
		spawn_requests = make([dynamic]Spawn_Request, 0, 100),
	}
}

game_data_deinit :: proc(gd: ^Game_Data) {
	particle_system_deinit(&gd.particles)
	rl.UnloadTexture(gd.boulder_tex)
	rl.UnloadTexture(gd.heart_tex)

	rl.UnloadTexture(gd.player.sprite)

	for key, tex in gd.atlas.textures {
		rl.UnloadTexture(tex)
		delete(key)
	}
	delete(gd.atlas.textures)

	for name, val in gd.atlas.statics {
		delete(name)
		delete(val.texture_key)
	}
	delete(gd.atlas.statics)

	for name, val in gd.atlas.animations {
		delete(name)
		delete(val.texture_key)
		delete(val.rects)
	}
	delete(gd.atlas.animations)

	for tex in gd.weapons_tex {
		rl.UnloadTexture(tex)
	}
	delete(gd.weapons_tex)

	player_deinit(&gd.player)
	delete(gd.enemies)
	delete(gd.projectiles)
	delete(gd.melee_attacks)
	delete(gd.spawn_requests)
}

is_on_screen :: proc(pos: rl.Vector2, camera: rl.Camera2D) -> bool {
	screen_pos := rl.GetWorldToScreen2D(pos, camera)
	return(
		screen_pos.x >= 0 &&
		screen_pos.x < f32(rl.GetScreenWidth()) &&
		screen_pos.y >= 0 &&
		screen_pos.y < f32(rl.GetScreenHeight()) \
	)
}

is_in_bounds :: proc(pos: rl.Vector2, bounds: rl.Rectangle) -> bool {
	return(
		pos.x > bounds.x &&
		pos.x < bounds.x + bounds.width &&
		pos.y > bounds.y &&
		pos.y < bounds.y + bounds.height \
	)
}

generate_level_up_options :: proc(gd: ^Game_Data) {
	pool: [dynamic]Level_Up_Option
	defer delete(pool)

	for i in 0 ..< len(gd.player.attacks) {
		atk := &gd.player.attacks[i]
		if attack_total_upgrades(atk) >= MAX_UPGRADES_PER_ATTACK {continue}

		append(&pool, Level_Up_Option{attack_idx = i, upgrade_type = .Damage})
		append(&pool, Level_Up_Option{attack_idx = i, upgrade_type = .Cooldown})

		switch _ in atk.attack_type {
		case Projectile_Config:
			append(&pool, Level_Up_Option{attack_idx = i, upgrade_type = .Projectiles})
		case Melee_Config:
			append(&pool, Level_Up_Option{attack_idx = i, upgrade_type = .Reach})
		}
	}

	// Fisher-Yates shuffle
	for i := len(pool) - 1; i > 0; i -= 1 {
		j := int(rand.float32() * f32(i + 1))
		pool[i], pool[j] = pool[j], pool[i]
	}

	gd.level_up_count = min(3, len(pool))
	for i in 0 ..< gd.level_up_count {
		gd.level_up_options[i] = pool[i]
	}
}
