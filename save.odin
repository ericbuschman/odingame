package main

import "core:encoding/json"
import "core:fmt"
import "core:os"

SAVE_DIR :: "saves"
SAVE_PATH :: "saves/save.json"

Attack_Upgrades_Save :: struct {
	damage:      i32 `json:"damage"`,
	projectiles: i32 `json:"projectiles"`,
	reach:       i32 `json:"reach"`,
	cooldown:    i32 `json:"cooldown"`,
}

Player_Save :: struct {
	loc_x:           f32                    `json:"loc_x"`,
	loc_y:           f32                    `json:"loc_y"`,
	health:          i32                    `json:"health"`,
	speed:           f32                    `json:"speed"`,
	score:           u32                    `json:"score"`,
	attack_upgrades: []Attack_Upgrades_Save `json:"attack_upgrades"`,
	is_dead:         bool                   `json:"is_dead"`,
}

Spawner_Save :: struct {
	enemy_id:     i32 `json:"enemy_id"`,
	enemy1_timer: f32 `json:"enemy1_timer"`,
}

Enemy_Save :: struct {
	loc_x:       f32    `json:"loc_x"`,
	loc_y:       f32    `json:"loc_y"`,
	personality: int    `json:"personality"`,
	health:      i32    `json:"health"`,
	speed:       f32    `json:"speed"`,
	scale:       f32    `json:"scale"`,
	proj_speed:  f32    `json:"proj_speed"`,
	proj_radius: f32    `json:"proj_radius"`,
	atk_damage:  i32    `json:"atk_damage"`,
	atk_interval: f32   `json:"atk_interval"`,
}

Save_File :: struct {
	player:  Player_Save   `json:"player"`,
	spawner: Spawner_Save  `json:"spawner"`,
	enemies: []Enemy_Save  `json:"enemies"`,
}

save_game :: proc(game: ^Game) -> bool {
	p := &game.game_data.player
	s := &game.spawner
	gd := &game.game_data

	enemy_saves := make([]Enemy_Save, len(gd.enemies))
	defer delete(enemy_saves)

	for e, i in gd.enemies {
		es := Enemy_Save {
			loc_x       = e.loc.x,
			loc_y       = e.loc.y,
			personality  = int(e.personality),
			health       = e.health,
			speed        = e.speed,
			scale        = e.scale,
		}
		// All current enemies have exactly one Projectile_Config attack
		if len(e.attacks) > 0 {
			atk := e.attacks[0]
			es.atk_damage   = atk.damage
			es.atk_interval = atk.interval
			if cfg, ok := atk.attack_type.(Projectile_Config); ok {
				es.proj_speed  = cfg.speed
				es.proj_radius = cfg.radius
			}
		}
		enemy_saves[i] = es
	}

	attack_upgrade_saves := make([]Attack_Upgrades_Save, len(p.attacks))
	defer delete(attack_upgrade_saves)
	for atk, i in p.attacks {
		attack_upgrade_saves[i] = Attack_Upgrades_Save {
			damage      = atk.upgrades.damage,
			projectiles = atk.upgrades.projectiles,
			reach       = atk.upgrades.reach,
			cooldown    = atk.upgrades.cooldown,
		}
	}

	sf := Save_File {
		player = Player_Save {
			loc_x           = p.loc.x,
			loc_y           = p.loc.y,
			health          = p.health,
			speed           = p.speed,
			score           = p.score,
			attack_upgrades = attack_upgrade_saves,
			is_dead         = p.health <= 0,
		},
		spawner = Spawner_Save{enemy_id = s.enemy_id, enemy1_timer = s.enemy1_timer},
		enemies = enemy_saves,
	}

	data, err := json.marshal(sf)
	if err != nil {
		fmt.eprintln("Failed to marshal save:", err)
		return false
	}
	defer delete(data)

	os.make_directory(SAVE_DIR)
	if write_err := os.write_entire_file(SAVE_PATH, data); write_err != nil {
		draw_fatal_error(fmt.tprintf("Could not write save file: %v", write_err))
	}

	fmt.println("Game saved.")
	return true
}

save_load :: proc(game: ^Game) -> bool {
	data, read_err := os.read_entire_file_from_path(SAVE_PATH, context.allocator)
	if read_err != nil {
		fmt.eprintln("No save file found")
		return false
	}
	defer delete(data)

	sf: Save_File
	err := json.unmarshal(data, &sf)
	if err != nil {
		fmt.eprintln("Failed to parse save:", err)
		return false
	}
	defer delete(sf.enemies)
	defer delete(sf.player.attack_upgrades)

	if sf.player.is_dead {
		fmt.eprintln("Save file contains a dead character — deleting")
		save_delete()
		return false
	}

	gd := &game.game_data

	// Clear enemies spawned during game_init
	for &e in gd.enemies {enemy_deinit(&e)}
	clear(&gd.enemies)

	// Restore enemies
	for es in sf.enemies {
		name_buf: [64]byte
		name := fmt.bprintf(name_buf[:], "Enemy%d", sf.spawner.enemy_id)
		e := enemy_new(
			{es.loc_x, es.loc_y},
			gd.enemy_tex,
			name,
			Enemy_State(es.personality),
			es.speed,
			es.health,
		)
		e.scale = es.scale
		append(
			&e.attacks,
			make_attack(
				"PewPew",
				Projectile_Config{speed = es.proj_speed, radius = es.proj_radius},
				es.atk_damage,
				es.atk_interval,
			),
		)
		append(&gd.enemies, e)
	}

	p := &game.game_data.player
	// Reset attacks to defaults first, then apply saved upgrade levels
	player_apply_defaults(p)

	p.loc.x  = sf.player.loc_x
	p.loc.y  = sf.player.loc_y
	p.health = sf.player.health
	p.speed  = sf.player.speed
	p.score  = sf.player.score

	for i in 0 ..< min(len(sf.player.attack_upgrades), len(p.attacks)) {
		saved := sf.player.attack_upgrades[i]
		p.attacks[i].upgrades.damage      = saved.damage
		p.attacks[i].upgrades.projectiles = saved.projectiles
		p.attacks[i].upgrades.reach       = saved.reach
		p.attacks[i].upgrades.cooldown    = saved.cooldown
	}

	game.spawner.enemy_id     = sf.spawner.enemy_id
	game.spawner.enemy1_timer = sf.spawner.enemy1_timer

	fmt.println("Game loaded.")
	return true
}

save_exists :: proc() -> bool {
	return os.exists(SAVE_PATH)
}

save_delete :: proc() {
	if os.exists(SAVE_PATH) {
		os.remove(SAVE_PATH)
	}
}
