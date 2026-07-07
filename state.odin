package main

import rl "vendor:raylib"

Game_State :: enum {
	Playing,
	Paused,
	Level_Up,
	Game_Over,
	Quit,
}

Move_Dir :: enum {
	Up,
	Down,
	Left,
	Right,
	None,
}

Anim_State :: enum {
	Idle,
	Walk,
	Attack,
}


Game_State_Result :: struct {
	new_state:        Game_State,
	time_accumulator: f32,
	skip_loop:        bool,
}

process_game_state :: proc(state: Game_State, gd: ^Game_Data) -> Game_State_Result {
	new_state := state
	time_accumulator: f32 = 0
	skip_loop := false

	switch new_state {
	case .Playing:
		if rl.IsKeyPressed(.ESCAPE) {
			new_state = .Paused
			gd.menu_nav = menu_nav_open()
		}
		time_accumulator += rl.GetFrameTime()

	case .Paused:
		if rl.IsKeyPressed(.ESCAPE) {
			new_state = .Playing
			gd.menu_nav = menu_nav_open()
		} else {
			skip_loop = true
		}

	case .Level_Up:
		skip_loop = true

	case .Game_Over:
		skip_loop = true

	case .Quit:
		skip_loop = true
	}

	return Game_State_Result {
		new_state = new_state,
		time_accumulator = time_accumulator,
		skip_loop = skip_loop,
	}
}
