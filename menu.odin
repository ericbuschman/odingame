package main

import "core:fmt"
import "core:math"
import rl "vendor:raylib"

main_menu_update :: proc(app: ^App) {
	sw := f32(SCREEN_WIDTH)
	sh := f32(SCREEN_HEIGHT)
	mouse := rl.GetMousePosition()

	// Title
	title :: "OdinGame"
	title_size: i32 = 50
	title_w := rl.MeasureText(title, title_size)
	rl.DrawText(title, i32(sw) / 2 - title_w / 2, 100, title_size, rl.WHITE)

	// Buttons
	btn_w: f32 = 250
	btn_h: f32 = 50
	btn_x := sw / 2 - btn_w / 2
	btn_start_y: f32 = 220
	btn_spacing: f32 = 20

	new_game_rect := rl.Rectangle{btn_x, btn_start_y, btn_w, btn_h}
	load_game_rect := rl.Rectangle{btn_x, btn_start_y + (btn_h + btn_spacing), btn_w, btn_h}
	settings_rect := rl.Rectangle{btn_x, btn_start_y + (btn_h + btn_spacing) * 2, btn_w, btn_h}
	quit_rect := rl.Rectangle{btn_x, btn_start_y + (btn_h + btn_spacing) * 3, btn_w, btn_h}

	if draw_menu_button(new_game_rect, "New Game", mouse) {
		// Clean up existing game if any
		if g, ok := &app.game.?; ok {
			game_deinit(g)
			app.game = nil
		}

		game, init_ok := game_init()
		if init_ok {
			app.game = game
			app.state = .Playing
		}
	}

	if draw_menu_button(load_game_rect, "Load Game", mouse) {
		if save_exists() {
			// Clean up existing game if any
			if g, ok := &app.game.?; ok {
				game_deinit(g)
				app.game = nil
			}

			game, init_ok := game_init()
			if init_ok {
				if save_load(&game) {
					app.game = game
					app.state = .Playing
				} else {
					game_deinit(&game)
				}
			}
		}
	}

	if draw_menu_button(settings_rect, "Settings", mouse) {
		app.state = .Settings
	}

	if draw_menu_button(quit_rect, "Quit", mouse) {
		app.state = .Quitting
	}

	// Show "no save" hint if hovering load with no save file
	if !save_exists() && rl.CheckCollisionPointRec(mouse, load_game_rect) {
		hint :: "No save file found"
		hint_size: i32 = 16
		hint_w := rl.MeasureText(hint, hint_size)
		rl.DrawText(
			hint,
			i32(sw) / 2 - hint_w / 2,
			i32(load_game_rect.y + load_game_rect.height) + 5,
			hint_size,
			rl.GRAY,
		)
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
	}
}

draw_menu_button :: proc(rect: rl.Rectangle, text: cstring, mouse_pos: rl.Vector2) -> bool {
	hovered := rl.CheckCollisionPointRec(mouse_pos, rect)

	if hovered {
		time := f32(rl.GetTime())
		osc := (math.sin(time * 5) + 1) / 2
		alpha := 0.3 + osc * 0.4

		glow_pad: f32 = 4
		glow_rect := rl.Rectangle {
			rect.x - glow_pad,
			rect.y - glow_pad,
			rect.width + glow_pad * 2,
			rect.height + glow_pad * 2,
		}
		rl.DrawRectangleRec(glow_rect, rl.Fade(rl.BLUE, f32(alpha)))

		if rl.IsMouseButtonPressed(.LEFT) {
			return true
		}
	}

	rl.DrawRectangleRec(rect, rl.DARKGRAY)
	rl.DrawRectangleLinesEx(rect, 2, rl.SKYBLUE if hovered else rl.WHITE)

	font_size: i32 = 24
	text_w := rl.MeasureText(text, font_size)
	text_x := rect.x + (rect.width - f32(text_w)) / 2
	text_y := rect.y + (rect.height - f32(font_size)) / 2
	rl.DrawText(text, i32(text_x), i32(text_y), font_size, rl.WHITE)

	return false
}
