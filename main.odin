package main

import "core:os"
import rl "vendor:raylib"

main :: proc() {
	rl.SetTraceLogLevel(.WARNING)
	rl.InitWindow(SCREEN_WIDTH, SCREEN_HEIGHT, "OdinGame")
	defer rl.CloseWindow()
	rl.SetTargetFPS(60)
	rl.SetExitKey(.KEY_NULL)

	for arg in os.args[1:] {
		if arg == "--test-write-error" {
			draw_fatal_error("Simulated write error: permission denied")
		}
	}

	app := App {
		state    = .Main_Menu,
		settings = settings_load(),
	}
	settings_apply(app.settings)

	for !rl.WindowShouldClose() && app.state != .Quitting {
		rl.BeginDrawing()
		rl.ClearBackground(rl.BLACK)

		switch app.state {
		case .Main_Menu:
			main_menu_update(&app)
		case .Settings:
			settings_menu_update(&app)
		case .Playing:
			game_update(&app)
		case .Quitting:
		// handled by loop condition
		}

		rl.EndDrawing()
	}

	// Cleanup
	if t, ok := app.game.?; ok {
		game_deinit(&t)
	}
	settings_save(app.settings)
}
