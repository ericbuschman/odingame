package main

import "core:fmt"
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

Game_State_Result :: struct {
	new_state:        Game_State,
	time_accumulator: f32,
	skip_loop:        bool,
	is_restart:       bool,
}

process_game_state :: proc(state: Game_State, gd: ^Game_Data) -> Game_State_Result {
	new_state := state
	time_accumulator: f32 = 0
	skip_loop := false
	is_restart := false

	switch new_state {
	case .Playing:
		if rl.IsKeyPressed(.ESCAPE) {
			new_state = .Paused
		}
		time_accumulator += rl.GetFrameTime()

	case .Paused:
		if rl.IsKeyPressed(.ESCAPE) {
			new_state = .Playing
		}
		if rl.IsKeyPressed(.Q) {
			new_state = .Quit
		} else {
			print_centered_text("Game Paused\nPress [Esc] to Return, [Q] to Quit", gd.camera, 0)
		}
		skip_loop = true

	case .Level_Up:
		if draw_level_up(gd) {
			new_state = .Playing
		} else {
			skip_loop = true
		}

	case .Game_Over:
		buf: [256]byte
		score_text := fmt.bprintf(buf[:], "Game Over\nScore: %d\nPress [R] to Replay, [Q] to Quit\x00", gd.player.score)
		print_centered_text(string(score_text), gd.camera, 0)

		key := rl.GetKeyPressed()
		#partial switch key {
		case .R:
			is_restart = true
			new_state = .Playing
		case .Q:
			new_state = .Quit
		case:
		}
		skip_loop = true

	case .Quit:
		skip_loop = true
	}

	return Game_State_Result {
		new_state        = new_state,
		time_accumulator = time_accumulator,
		skip_loop        = skip_loop,
		is_restart       = is_restart,
	}
}
