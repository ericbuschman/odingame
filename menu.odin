package main

import "core:fmt"
import "core:math"
import "core:strings"
import rl "vendor:raylib"

// ---------------------------------------------------------------------------
// Menu system types
// ---------------------------------------------------------------------------

Menu_Item_Style :: struct {
	size:      rl.Vector2,
	font_size: i32,
	bg:        rl.Color,
	border:    rl.Color,
	border_hl: rl.Color, // hovered / keyboard-selected
	glow:      rl.Color,
	glow_pad:  f32,
}

BUTTON_STYLE :: Menu_Item_Style {
	size      = {250, 50},
	font_size = 24,
	bg        = rl.DARKGRAY,
	border    = rl.WHITE,
	border_hl = rl.SKYBLUE,
	glow      = rl.BLUE,
	glow_pad  = 4,
}

CARD_STYLE :: Menu_Item_Style {
	size      = {180, 200},
	font_size = 20,
	bg        = rl.DARKGRAY,
	border    = rl.WHITE,
	border_hl = rl.SKYBLUE,
	glow      = rl.BLUE,
	glow_pad  = 6,
}

Menu_Button :: struct {
	label:    string,
	hotkey:   rl.KeyboardKey, // .KEY_NULL = no hotkey
	disabled: bool,
}

Menu_Layout :: enum {
	Vertical,
	Horizontal,
}

Menu_Def :: struct {
	label:      string, // header; \n supported; "" = no header
	layout:     Menu_Layout,
	buttons:    []Menu_Button, // stack-allocated slice from caller
	item_style: Menu_Item_Style,
}

Menu_Nav :: struct {
	selected:    int, // index into buttons; 0 = first item
	just_opened: bool, // true on first frame — skip all input to avoid key bleed from previous state
}

menu_nav_open :: proc() -> Menu_Nav {
	return Menu_Nav{selected = 0, just_opened = true}
}

MENU_MAX_COLS :: 3
MENU_ITEM_SPACING :: f32(20)
MENU_LABEL_GAP :: f32(30)
MENU_LABEL_FS :: i32(30)
MENU_LABEL_LS :: i32(4)

// ---------------------------------------------------------------------------
// Helper procs
// ---------------------------------------------------------------------------

count_lines :: proc(s: string) -> int {
	if len(s) == 0 {return 0}
	n := 1
	for c in s {
		if c == '\n' {n += 1}
	}
	return n
}

measure_label_height :: proc(label: string, font_size, line_spacing: i32) -> f32 {
	if len(label) == 0 {return 0}
	n := i32(count_lines(label))
	return f32(n * font_size + max(0, n - 1) * line_spacing)
}

draw_menu_label :: proc(label: string, cx, top_y: f32, font_size, line_spacing: i32) {
	y := top_y
	tmp := label
	for line in strings.split_lines_iterator(&tmp) {
		c := fmt.ctprintf("%s", line)
		w := rl.MeasureText(c, font_size)
		rl.DrawText(c, i32(cx) - w / 2, i32(y), font_size, rl.WHITE)
		y += f32(font_size + line_spacing)
	}
}

// Centers multi-line word-wrapped text inside rect.
draw_item_text :: proc(rect: rl.Rectangle, text: string, font_size: i32, color: rl.Color) {
	padding: i32 = 10
	max_w := i32(rect.width) - padding * 2
	buf: [512]byte
	wrapped, ok := word_wrap(text, buf[:], max_w, font_size)
	if !ok {return}

	line_spacing: i32 = 2
	num_lines: i32 = 0
	{
		tmp := wrapped
		for _ in strings.split_lines_iterator(&tmp) {num_lines += 1}
	}
	if num_lines == 0 {return}

	block_h := num_lines * font_size + (num_lines - 1) * line_spacing
	start_y := rect.y + (rect.height - f32(block_h)) / 2

	{
		tmp := wrapped
		line_idx: i32 = 0
		for line in strings.split_lines_iterator(&tmp) {
			c := fmt.ctprintf("%s", line)
			w := rl.MeasureText(c, font_size)
			x := rect.x + (rect.width - f32(w)) / 2
			y := start_y + f32(line_idx * (font_size + line_spacing))
			rl.DrawText(c, i32(x), i32(y), font_size, color)
			line_idx += 1
		}
	}
}

next_enabled :: proc(buttons: []Menu_Button, current, n: int) -> int {
	for i in 1 ..< n {
		idx := (current + i) % n
		if !buttons[idx].disabled {return idx}
	}
	return current
}

prev_enabled :: proc(buttons: []Menu_Button, current, n: int) -> int {
	for i in 1 ..< n {
		idx := (current - i + n) % n
		if !buttons[idx].disabled {return idx}
	}
	return current
}

// ---------------------------------------------------------------------------
// draw_menu — generalized menu engine
// ---------------------------------------------------------------------------

draw_menu :: proc(def: Menu_Def, nav: ^Menu_Nav, screen_center: rl.Vector2) -> int {
	n := len(def.buttons)
	if n == 0 {return -1}

	item_w := def.item_style.size.x
	item_h := def.item_style.size.y

	// Grid dimensions
	num_cols := 1
	if def.layout == .Horizontal {
		num_cols = min(n, MENU_MAX_COLS)
	}
	num_rows := (n + num_cols - 1) / num_cols
	grid_w := f32(num_cols) * item_w + f32(num_cols - 1) * MENU_ITEM_SPACING
	grid_h := f32(num_rows) * item_h + f32(num_rows - 1) * MENU_ITEM_SPACING

	// Label block
	label_h := measure_label_height(def.label, MENU_LABEL_FS, MENU_LABEL_LS)
	label_gap: f32 = MENU_LABEL_GAP if len(def.label) > 0 else 0

	total_h := label_h + label_gap + grid_h
	origin_y := screen_center.y - total_h / 2
	origin_x := screen_center.x - grid_w / 2

	// Draw label
	if len(def.label) > 0 {
		draw_menu_label(def.label, screen_center.x, origin_y, MENU_LABEL_FS, MENU_LABEL_LS)
	}

	items_start_y := origin_y + label_h + label_gap

	// Consume the just_opened flag — skip all input this frame to prevent key
	// bleed from whatever triggered the state transition (e.g. holding D when
	// an enemy dies, or Escape opening the pause menu).
	first_frame := nav.just_opened
	if first_frame {
		nav.just_opened = false
	}

	// Arrow-key navigation (arrow keys only — avoids W/A/S/D conflicts).
	// Skipped on first frame.
	if !first_frame {
		if def.layout == .Vertical {
			if rl.IsKeyPressed(.UP) {
				nav.selected = prev_enabled(def.buttons, nav.selected, n)
			}
			if rl.IsKeyPressed(.DOWN) {
				nav.selected = next_enabled(def.buttons, nav.selected, n)
			}
		} else {
			if rl.IsKeyPressed(.LEFT) {
				nav.selected = prev_enabled(def.buttons, nav.selected, n)
			}
			if rl.IsKeyPressed(.RIGHT) {
				nav.selected = next_enabled(def.buttons, nav.selected, n)
			}
			if rl.IsKeyPressed(.UP) {
				candidate := nav.selected - num_cols
				if candidate >= 0 && !def.buttons[candidate].disabled {
					nav.selected = candidate
				}
			}
			if rl.IsKeyPressed(.DOWN) {
				candidate := nav.selected + num_cols
				if candidate < n && !def.buttons[candidate].disabled {
					nav.selected = candidate
				}
			}
		}
	}

	mouse := rl.GetMousePosition()

	// Draw items
	rects: [32]rl.Rectangle
	for i in 0 ..< n {
		col := i % num_cols
		row := i / num_cols
		rects[i] = rl.Rectangle {
			x      = origin_x + f32(col) * (item_w + MENU_ITEM_SPACING),
			y      = items_start_y + f32(row) * (item_h + MENU_ITEM_SPACING),
			width  = item_w,
			height = item_h,
		}

		btn := def.buttons[i]
		rect := rects[i]

		hovered := !btn.disabled && rl.CheckCollisionPointRec(mouse, rect)
		if hovered {
			nav.selected = i
		}
		is_selected := !btn.disabled && nav.selected == i

		if hovered || is_selected {
			t := f32(rl.GetTime())
			osc := (math.sin(t * 5) + 1) / 2
			alpha := f32(0.3 + osc * 0.4)
			gp := def.item_style.glow_pad
			glow_rect := rl.Rectangle {
				x      = rect.x - gp,
				y      = rect.y - gp,
				width  = rect.width + gp * 2,
				height = rect.height + gp * 2,
			}
			rl.DrawRectangleRec(glow_rect, rl.Fade(def.item_style.glow, alpha))
		}

		bg := def.item_style.bg
		if btn.disabled {bg = rl.Fade(bg, 0.4)}
		rl.DrawRectangleRec(rect, bg)

		border := def.item_style.border_hl if (hovered || is_selected) else def.item_style.border
		if btn.disabled {border = rl.Fade(border, 0.3)}
		rl.DrawRectangleLinesEx(rect, 2, border)

		text_color := rl.WHITE if !btn.disabled else rl.Fade(rl.WHITE, 0.35)
		draw_item_text(rect, btn.label, def.item_style.font_size, text_color)
	}

	// No activation on the first frame shown.
	if first_frame {return -1}

	// Activation: hotkeys, then Enter on keyboard selection, then mouse click.
	for i in 0 ..< n {
		btn := def.buttons[i]
		if btn.disabled {continue}
		if btn.hotkey != .KEY_NULL && rl.IsKeyPressed(btn.hotkey) {
			return i
		}
	}
	if nav.selected >= 0 && nav.selected < n {
		btn := def.buttons[nav.selected]
		if !btn.disabled && rl.IsKeyPressed(.ENTER) {
			return nav.selected
		}
	}
	for i in 0 ..< n {
		btn := def.buttons[i]
		if btn.disabled {continue}
		if rl.CheckCollisionPointRec(mouse, rects[i]) && rl.IsMouseButtonPressed(.LEFT) {
			return i
		}
	}

	return -1
}

// ---------------------------------------------------------------------------
// In-game overlay menus (called from game_update after EndMode2D)
// ---------------------------------------------------------------------------

draw_pause_menu :: proc(app: ^App) {
	game, ok := &app.game.?
	if !ok {return}
	gd := &game.game_data

	buttons := [2]Menu_Button {
		{label = "[Esc] Resume", hotkey = .KEY_NULL}, // Esc toggle handled by process_game_state
		{label = "[Q]uit", hotkey = .Q},
	}
	def := Menu_Def {
		label      = "Game Paused",
		layout     = .Vertical,
		buttons    = buttons[:],
		item_style = BUTTON_STYLE,
	}
	center := rl.Vector2{f32(SCREEN_WIDTH) / 2, f32(SCREEN_HEIGHT) / 2}
	result := draw_menu(def, &gd.menu_nav, center)

	switch result {
	case 0:
		gd.state = .Playing
		gd.menu_nav = menu_nav_open()
	case 1:
		gd.state = .Quit
		gd.menu_nav = menu_nav_open()
	}
}

draw_game_over_menu :: proc(app: ^App) {
	game, ok := &app.game.?
	if !ok {return}
	gd := &game.game_data

	label_buf: [64]byte
	label := fmt.bprintf(label_buf[:], "Game Over\nScore: %d", gd.player.score)

	buttons := [2]Menu_Button {
		{label = "[R]eplay", hotkey = .R},
		{label = "[Q]uit to Menu", hotkey = .Q},
	}
	def := Menu_Def {
		label      = label,
		layout     = .Vertical,
		buttons    = buttons[:],
		item_style = BUTTON_STYLE,
	}
	center := rl.Vector2{f32(SCREEN_WIDTH) / 2, f32(SCREEN_HEIGHT) / 2}
	result := draw_menu(def, &gd.menu_nav, center)

	switch result {
	case 0:
		game_restart(gd)
		gd.state = .Playing
		gd.menu_nav = menu_nav_open()
	case 1:
		gd.state = .Quit
		gd.menu_nav = menu_nav_open()
	}
}

draw_level_up_menu :: proc(app: ^App) {
	game, ok := &app.game.?
	if !ok {return}
	gd := &game.game_data

	buttons := [2]Menu_Button {
		{label = "[D]amage+", hotkey = .D},
		{label = "[P]rojectile+", hotkey = .P},
	}
	def := Menu_Def {
		label      = "LEVEL UP!",
		layout     = .Horizontal,
		buttons    = buttons[:],
		item_style = CARD_STYLE,
	}
	center := rl.Vector2{f32(SCREEN_WIDTH) / 2, f32(SCREEN_HEIGHT) / 2}
	result := draw_menu(def, &gd.menu_nav, center)

	switch result {
	case 0:
		gd.player.damage_level += 1
		gd.state = .Playing
		gd.menu_nav = menu_nav_open()
	case 1:
		gd.player.proj_count_level += 1
		gd.state = .Playing
		gd.menu_nav = menu_nav_open()
	}
}

// ---------------------------------------------------------------------------
// App-level menus
// ---------------------------------------------------------------------------

main_menu_update :: proc(app: ^App) {
	has_save := save_exists()

	buttons := [4]Menu_Button {
		{label = "[N]ew Game", hotkey = .N},
		{label = "[L]oad Game", hotkey = .L, disabled = !has_save},
		{label = "[S]ettings", hotkey = .S},
		{label = "[Q]uit", hotkey = .Q},
	}
	def := Menu_Def {
		label      = "OdinGame",
		layout     = .Vertical,
		buttons    = buttons[:],
		item_style = BUTTON_STYLE,
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
