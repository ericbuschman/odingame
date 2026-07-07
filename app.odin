package main

import "core:encoding/json"
import "core:fmt"
import "core:os"
import rl "vendor:raylib"

App_State :: enum {
	Main_Menu,
	Settings,
	Playing,
	Quitting,
}

App_Settings :: struct {
	master_volume: f32,
	fullscreen:    bool,
}

App :: struct {
	state:    App_State,
	game:     Maybe(Game),
	settings: App_Settings,
	menu_nav: Menu_Nav,
}

SETTINGS_PATH :: "settings.json"

Settings_Json :: struct {
	master_volume: f32 `json:"master_volume"`,
	fullscreen:    bool `json:"fullscreen"`,
}

settings_load :: proc() -> App_Settings {
	data, read_err := os.read_entire_file_from_path(SETTINGS_PATH, context.allocator)
	if read_err != nil {
		return App_Settings{master_volume = 0.8, fullscreen = false}
	}
	defer delete(data)

	sj: Settings_Json
	err := json.unmarshal(data, &sj)
	if err != nil {
		fmt.eprintln("Failed to parse settings:", err)
		return App_Settings{master_volume = 0.8, fullscreen = false}
	}

	return App_Settings{master_volume = clamp(sj.master_volume, 0, 1), fullscreen = sj.fullscreen}
}

settings_save :: proc(s: App_Settings) {
	sj := Settings_Json {
		master_volume = s.master_volume,
		fullscreen    = s.fullscreen,
	}

	data, err := json.marshal(sj)
	if err != nil {
		fmt.eprintln("Failed to marshal settings:", err)
		return
	}
	defer delete(data)

	if write_err := os.write_entire_file(SETTINGS_PATH, data); write_err != nil {
		draw_fatal_error(fmt.tprintf("Could not write settings file: %v", write_err))
	}
}

settings_apply :: proc(s: App_Settings) {
	rl.SetMasterVolume(s.master_volume)
}

main_menu_update :: proc(app: ^App) {
	has_save := save_exists()

	items := [4]Menu_Item {
		{label = "[N]ew Game", hotkeys = {rl.KeyboardKey.N, nil}},
		{label = "[L]oad Game", hotkeys = {rl.KeyboardKey.L, nil}, disabled = !has_save},
		{label = "[S]ettings", hotkeys = {rl.KeyboardKey.S, nil}},
		{label = "[Q]uit", hotkeys = {rl.KeyboardKey.Q, nil}},
	}
	def := Menu_Def {
		label       = "OdinGame",
		layout      = .Vertical,
		items       = items[:],
		style       = BUTTON_STYLE,
		interaction = MENU_INTERACT_NO_SCROLL,
	}
	center := rl.Vector2{f32(SCREEN_WIDTH) / 2, f32(SCREEN_HEIGHT) / 2}
	result := draw_menu(def, &app.menu_nav, center)

	switch result {
	case 0:
		// New Game
		if g, ok := &app.game.?; ok {
			game_deinit(g)
			app.game = nil
		}
		game, init_ok := game_init()
		if init_ok {
			app.game = game
			app.state = .Playing
			app.menu_nav = menu_nav_open()
		}
	case 1:
		// Load Game
		if has_save {
			if g, ok := &app.game.?; ok {
				game_deinit(g)
				app.game = nil
			}
			game, init_ok := game_init()
			if init_ok {
				if save_load(&game) {
					app.game = game
					app.state = .Playing
					app.menu_nav = menu_nav_open()
				} else {
					game_deinit(&game)
				}
			}
		}
	case 2:
		// Settings
		app.state = .Settings
		app.menu_nav = menu_nav_open()
	case 3:
		// Quit
		app.state = .Quitting
	}
}

settings_menu_update :: proc(app: ^App) {
	sw := f32(SCREEN_WIDTH)
	mouse := rl.GetMousePosition()

	// Title
	title :: "Settings"
	title_size: i32 = 40
	title_w := rl.MeasureText(title, title_size)
	rl.DrawText(title, i32(sw) / 2 - title_w / 2, 100, title_size, rl.WHITE)

	// Volume control
	label_y: i32 = 220
	label :: "Volume"
	label_size: i32 = 24
	rl.DrawText(label, i32(sw / 2) - 120, label_y, label_size, rl.WHITE)

	// Volume bar
	bar_x: f32 = sw / 2 - 50
	bar_y: f32 = f32(label_y) + 2
	bar_w: f32 = 160
	bar_h: f32 = 20
	bar_rect := rl.Rectangle{bar_x, bar_y, bar_w, bar_h}

	rl.DrawRectangleRec(bar_rect, rl.DARKGRAY)
	fill_rect := rl.Rectangle{bar_x, bar_y, bar_w * app.settings.master_volume, bar_h}
	rl.DrawRectangleRec(fill_rect, rl.GREEN)
	rl.DrawRectangleLinesEx(bar_rect, 1, rl.WHITE)

	// Click to set volume
	if rl.IsMouseButtonDown(.LEFT) && rl.CheckCollisionPointRec(mouse, bar_rect) {
		app.settings.master_volume = clamp((mouse.x - bar_x) / bar_w, 0, 1)
		settings_apply(app.settings)
	}

	// Volume percentage text
	vol_buf: [16]byte
	vol_text := fmt.bprintf(vol_buf[:], "%d%%\x00", int(app.settings.master_volume * 100))
	rl.DrawText(
		cstring(raw_data(vol_text)),
		i32(bar_x + bar_w) + 10,
		label_y,
		label_size,
		rl.WHITE,
	)

	// Fullscreen toggle
	fs_y: f32 = f32(label_y) + 60
	fs_rect := rl.Rectangle{sw / 2 - 125, fs_y, 250, 50}
	fs_label: cstring = "Fullscreen: ON" if app.settings.fullscreen else "Fullscreen: OFF"

	if draw_menu_button(fs_rect, fs_label, mouse) {
		app.settings.fullscreen = !app.settings.fullscreen
		rl.ToggleFullscreen()
	}

	// Back button
	back_y: f32 = fs_y + 100
	back_rect := rl.Rectangle{sw / 2 - 125, back_y, 250, 50}

	if draw_menu_button(back_rect, "Back", mouse) {
		settings_save(app.settings)
		app.state = .Main_Menu
		app.menu_nav = menu_nav_open()
	}
}

// draw_fatal_error shows a blocking error dialog using the standard menu
// renderer, waits for the player to dismiss it, then exits the process.
draw_fatal_error :: proc(msg: string) {
	label_buf: [256]byte
	label := fmt.bprintf(label_buf[:], "Fatal Error\n%s", msg)
	nav := menu_nav_open()
	items := [1]Menu_Item{{label = "[Enter] Quit", hotkeys = {rl.KeyboardKey.ENTER, nil}}}
	def := Menu_Def {
		label       = label,
		layout      = .Vertical,
		items       = items[:],
		style       = BUTTON_STYLE,
		interaction = MENU_INTERACT_NO_SCROLL,
	}
	center := rl.Vector2{f32(SCREEN_WIDTH) / 2, f32(SCREEN_HEIGHT) / 2}
	for !rl.WindowShouldClose() {
		rl.BeginDrawing()
		rl.ClearBackground(rl.BLACK)
		result := draw_menu(def, &nav, center)
		rl.EndDrawing()
		if result >= 0 {break}
	}
	os.exit(1)
}
