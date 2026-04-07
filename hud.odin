package main

import "core:fmt"
import rl "vendor:raylib"

draw_hud :: proc(
	heart_tex: rl.Texture2D,
	hp: i32,
	attacks: []Attack,
	nav: ^Menu_Nav,
	selected_attack: ^Attack,
) -> ^Attack {
	if hp <= 0 {return selected_attack}

	// Hearts — plain screen coords, no camera needed
	for i in 0 ..< hp {
		pos := rl.Vector2{10 + f32(i) * 20, 10}
		rl.DrawTextureEx(heart_tex, pos, 0, 1, rl.RED)
	}

	// Attack cards — reuse draw_menu so styling/interaction is centralized
	n := min(len(attacks), 3)
	if n == 0 {return selected_attack}

	// Sync nav to the current selection
	for i in 0 ..< n {
		if &attacks[i] == selected_attack {
			nav.selected = i
			break
		}
	}

	buttons: [3]Menu_Button
	buf: [3][128]byte
	for i in 0 ..< n {
		atk := &attacks[i]
		eff_dmg := atk.damage * (1 + atk.upgrades.damage)
		eff_cd := attack_effective_interval(atk)

		label: string
		switch cfg in atk.attack_type {
		case Melee_Config:
			eff_reach := cfg.length + f32(atk.upgrades.reach) * REACH_PER_UPGRADE
			label = fmt.bprintf(
				buf[i][:],
				"[%d] %s\nDMG %d\nReach %.0f\nCD %.1fs",
				i + 1,
				atk.name,
				eff_dmg,
				eff_reach,
				eff_cd,
			)
		case Projectile_Config:
			proj_count := 1 + atk.upgrades.projectiles
			label = fmt.bprintf(
				buf[i][:],
				"[%d] %s\nDMG %d\nProj %d\nCD %.1fs",
				i + 1,
				atk.name,
				eff_dmg,
				proj_count,
				eff_cd,
			)
		}
		buttons[i] = Menu_Button {
			label   = label,
			hotkeys = {rl.KeyboardKey(i + 49), nil},
		}
	}

	def := Menu_Def {
		layout     = .Horizontal,
		buttons    = buttons[:n],
		item_style = CARD_STYLE,
	}

	card_h: f32 = 140
	card_w: f32 = 100
	margin: f32 = 2
	sw := f32(rl.GetScreenWidth())
	sh := f32(rl.GetScreenHeight())
	center := rl.Vector2{sw / 2, sh - card_h / 2 - margin}
	attack_selector := draw_menu(def, nav, center, card_w, card_h)
	if attack_selector >= 0 {
		fmt.printfln("Attack selected: %d", attack_selector)
	}
	if attack_selector >= 0 && &attacks[attack_selector] != selected_attack {
		return &attacks[attack_selector]
	}
	return selected_attack
}
