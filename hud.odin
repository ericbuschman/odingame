package main

import "core:fmt"
import rl "vendor:raylib"

draw_hud :: proc(heart_tex: rl.Texture2D, hp: i32, attacks: []Attack, nav: ^Menu_Nav) {
	if hp <= 0 {return}

	// Hearts — plain screen coords, no camera needed
	for i in 0 ..< hp {
		pos := rl.Vector2{10 + f32(i) * 20, 10}
		rl.DrawTextureEx(heart_tex, pos, 0, 1, rl.RED)
	}

	// Attack cards — reuse draw_menu so styling/interaction is centralized
	n := min(len(attacks), 3)
	if n == 0 {return}

	buttons: [3]Menu_Button
	buf: [3][64]byte
	for i in 0 ..< n {
		label := fmt.bprintf(
			buf[i][:],
			"%s\nDMG %d\nCD %.1fs",
			attacks[i].name,
			attacks[i].damage,
			attacks[i].interval,
		)
		buttons[i] = Menu_Button {
			label = label,
		}
	}

	def := Menu_Def {
		layout     = .Horizontal,
		buttons    = buttons[:n],
		item_style = CARD_STYLE,
	}

	card_h: f32 = 120
	card_w: f32 = 100
	margin: f32 = 2
	sw := f32(rl.GetScreenWidth())
	sh := f32(rl.GetScreenHeight())
	center := rl.Vector2{sw / 2, sh - card_h / 2 - margin}
	draw_menu(def, nav, center, card_w, card_h)
}
