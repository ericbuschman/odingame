package main

import "core:fmt"
import "core:math"
import "core:strings"
import rl "vendor:raylib"

draw_hud :: proc(heart_tex: rl.Texture2D, hp: i32, camera: ^rl.Camera2D) {
	if hp <= 0 {return}

	screen_loc := rl.GetScreenToWorld2D({10, 0}, camera^)

	for i in 0 ..< hp {
		offset := f32(i)
		pos := rl.Vector2{screen_loc.x + offset * 20, screen_loc.y + 10}
		rl.DrawTextureEx(heart_tex, pos, 0, 1, rl.RED)
	}
}

draw_level_up :: proc(gd: ^Game_Data) -> bool {
	sw := f32(rl.GetScreenWidth())
	sh := f32(rl.GetScreenHeight())

	center := rl.GetScreenToWorld2D({sw / 2, sh / 2}, gd.camera)

	panel_w: i32 = 500
	panel_h: i32 = 300
	panel_x := i32(center.x) - panel_w / 2
	panel_y := i32(center.y) - panel_h / 2

	draw_border(panel_x, panel_y, panel_w, panel_h)

	// Title
	title :: "LEVEL UP!"
	title_size: i32 = 30
	title_w := rl.MeasureText(title, title_size)
	rl.DrawText(title, i32(center.x) - title_w / 2, panel_y + 20, title_size, rl.WHITE)

	// Cards
	card_w: f32 = 180
	card_h: f32 = 200
	spacing: f32 = 40

	total_w := card_w * 2 + spacing
	cards_start_x := center.x - total_w / 2
	cards_y := center.y - card_h / 2 + 20

	left_card := rl.Rectangle{cards_start_x, cards_y, card_w, card_h}
	right_card := rl.Rectangle{cards_start_x + card_w + spacing, cards_y, card_w, card_h}

	mouse_world := rl.GetScreenToWorld2D(rl.GetMousePosition(), gd.camera)
	close_panel := false

	if draw_card(left_card, "Plus Damage", mouse_world) {
		gd.player.attack_upgrade = .Damage
		close_panel = true
	}
	if draw_card(right_card, "Additional Projectile", mouse_world) {
		gd.player.attack_upgrade = .Proj_Count
		close_panel = true
	}

	return close_panel
}

draw_card :: proc(rect: rl.Rectangle, text: cstring, mouse_pos: rl.Vector2) -> bool {
	hovered := rl.CheckCollisionPointRec(mouse_pos, rect)

	if hovered {
		time := f32(rl.GetTime())
		osc := (math.sin(time * 5) + 1) / 2
		alpha := 0.3 + osc * 0.4

		glow_pad: f32 = 6
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

	font_size: i32 = 20
	padding: i32 = 10
	max_width := i32(rect.width) - padding * 2

	wrapped_buf: [256]byte
	wrapped, ok := word_wrap(string(text), wrapped_buf[:], max_width, font_size)
	if !ok {return false}

	// Count lines and measure for centering
	num_lines: i32 = 0
	{
		tmp := wrapped
		for _ in strings.split_lines_iterator(&tmp) {
			num_lines += 1
		}
	}

	line_spacing: i32 = 2
	block_height := num_lines * font_size + (num_lines - 1) * line_spacing
	start_y := rect.y + (rect.height - f32(block_height)) / 2

	{
		tmp := wrapped
		line_idx: i32 = 0
		for line in strings.split_lines_iterator(&tmp) {
			c_line := fmt.ctprintf("%s", line)
			line_w := rl.MeasureText(c_line, font_size)
			x := rect.x + (rect.width - f32(line_w)) / 2
			y := start_y + f32(line_idx * (font_size + line_spacing))
			rl.DrawText(c_line, i32(x), i32(y), font_size, rl.WHITE)
			line_idx += 1
		}
	}

	return false
}
