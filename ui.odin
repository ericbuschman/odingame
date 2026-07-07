package main

import "core:fmt"
import rl "vendor:raylib"

draw_hud :: proc(
	heart_tex: rl.Texture2D,
	weapons_tex: []rl.Texture2D,
	hp: i32,
	attacks: []Attack,
	nav: ^Menu_Nav,
	selected_attack: ^Attack,
	interactive: bool,
) -> ^Attack {
	if hp <= 0 {return selected_attack}

	// Hearts
	for i in 0 ..< hp {
		pos := rl.Vector2{10 + f32(i) * 20, 10}
		rl.DrawTextureEx(heart_tex, pos, 0, 1, rl.RED)
	}

	// Attack cards
	n := min(len(attacks), 3)
	if n == 0 {return selected_attack}

	for i in 0 ..< n {
		if &attacks[i] == selected_attack {
			nav.selected = i
			break
		}
	}

	items: [3]Menu_Item
	item_textures: [3]rl.Texture2D
	buf: [3][128]byte
	for i in 0 ..< n {
		atk := &attacks[i]
		eff_dmg := atk.damage * (1 + atk.upgrades.damage)

		label := fmt.bprintf(
			buf[i][:],
			"%s\n%d DMG",
			atk.name,
			eff_dmg,
		)
		items[i] = Menu_Item {
			label   = label,
			hotkeys = {rl.KeyboardKey(i + 49), nil},
		}
		item_textures[i] = weapons_tex[atk.weapon_tex_idx]
	}

	def := Menu_Def {
		layout      = .Horizontal,
		items       = items[:n],
		style       = CARD_STYLE,
		interaction = MENU_INTERACT_SCROLL_KBD if interactive else {},
	}

	margin: f32 = 2
	scale: f32 = 0.5
	sw := f32(rl.GetScreenWidth())
	sh := f32(rl.GetScreenHeight())
	center := rl.Vector2{sw / 2, sh - (CARD_STYLE.item_h * scale) / 2 - margin}

	attack_selector := draw_icon_menu(
		def,
		nav,
		center,
		item_textures[:n],
		0.75,      // opacity
		rl.GRAY,   // border color
		2.0,       // border width
		scale,     // scale
	)

	if attack_selector >= 0 && &attacks[attack_selector] != selected_attack {
		return &attacks[attack_selector]
	}
	return selected_attack
}
