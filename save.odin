package main

import "core:encoding/json"
import "core:fmt"
import "core:os"

SAVE_DIR :: "saves"
SAVE_PATH :: "saves/save.json"

Player_Save :: struct {
	loc_x:            f32 `json:"loc_x"`,
	loc_y:            f32 `json:"loc_y"`,
	health:           i32 `json:"health"`,
	speed:            f32 `json:"speed"`,
	score:            u32 `json:"score"`,
	damage_level:     i32 `json:"damage_level"`,
	proj_count_level: i32 `json:"proj_count_level"`,
}

Spawner_Save :: struct {
	enemy_id:     i32 `json:"enemy_id"`,
	enemy1_timer: f32 `json:"enemy1_timer"`,
}

Save_File :: struct {
	player:  Player_Save `json:"player"`,
	spawner: Spawner_Save `json:"spawner"`,
}

save_game :: proc(game: ^Game) -> bool {
	p := &game.game_data.player
	s := &game.spawner

	sf := Save_File {
		player = Player_Save {
			loc_x = p.loc.x,
			loc_y = p.loc.y,
			health = p.health,
			speed = p.speed,
			score = p.score,
			damage_level = p.damage_level,
			proj_count_level = p.proj_count_level,
		},
		spawner = Spawner_Save{enemy_id = s.enemy_id, enemy1_timer = s.enemy1_timer},
	}

	data, err := json.marshal(sf)
	if err != nil {
		fmt.eprintln("Failed to marshal save:", err)
		return false
	}
	defer delete(data)

	os.make_directory(SAVE_DIR)
	if !os.write_entire_file(SAVE_PATH, data) {
		fmt.eprintln("Failed to write save file")
		return false
	}

	fmt.println("Game saved.")
	return true
}

save_load :: proc(game: ^Game) -> bool {
	data, ok := os.read_entire_file(SAVE_PATH)
	if !ok {
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

	p := &game.game_data.player
	// Reset attacks to defaults first, then apply saved upgrade levels
	player_apply_defaults(p)

	p.loc.x = sf.player.loc_x
	p.loc.y = sf.player.loc_y
	p.health = sf.player.health
	p.speed = sf.player.speed
	p.score = sf.player.score
	p.damage_level = sf.player.damage_level
	p.proj_count_level = sf.player.proj_count_level

	game.spawner.enemy_id = sf.spawner.enemy_id
	game.spawner.enemy1_timer = sf.spawner.enemy1_timer

	fmt.println("Game loaded.")
	return true
}

save_exists :: proc() -> bool {
	return os.exists(SAVE_PATH)
}
