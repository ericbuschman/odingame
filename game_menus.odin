package main

import "core:fmt"
import rl "vendor:raylib"

draw_pause_menu :: proc(app: ^App) {
	game, ok := &app.game.?
	if !ok {return}
	gd := &game.game_data

	items := [2]Menu_Item {
		{label = "[Esc] Resume"}, // Esc toggle handled by process_game_state
		{label = "[Q]uit", hotkeys = {rl.KeyboardKey.Q, nil}},
	}
	def := Menu_Def {
		label       = "Game Paused",
		layout      = .Vertical,
		items       = items[:],
		style       = BUTTON_STYLE,
		interaction = MENU_INTERACT_NO_SCROLL,
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

	items := [2]Menu_Item {
		{label = "[R]eplay", hotkeys = {rl.KeyboardKey.R, nil}},
		{label = "[Q]uit to Menu", hotkeys = {rl.KeyboardKey.Q, nil}},
	}
	def := Menu_Def {
		label       = label,
		layout      = .Vertical,
		items       = items[:],
		style       = BUTTON_STYLE,
		interaction = MENU_INTERACT_NO_SCROLL,
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

upgrade_type_name :: proc(t: Upgrade_Type) -> string {
	switch t {
	case .Damage:
		return "Damage"
	case .Projectiles:
		return "Projectiles"
	case .Reach:
		return "Reach"
	case .Cooldown:
		return "Cooldown"
	}
	return ""
}

draw_level_up_menu :: proc(app: ^App) {
	game, ok := &app.game.?
	if !ok {return}
	gd := &game.game_data

	// If no options available (all attacks fully upgraded), resume immediately
	if gd.level_up_count == 0 {
		gd.state = .Playing
		gd.menu_nav = menu_nav_open()
		return
	}

	label_bufs: [3][256]byte
	items: [3]Menu_Item

	for i in 0 ..< gd.level_up_count {
		opt := gd.level_up_options[i]
		atk := &gd.player.attacks[opt.attack_idx]

		old_buf: [32]byte
		new_buf: [32]byte
		old_val: string
		new_val: string

		switch opt.upgrade_type {
		case .Damage:
			old_val = fmt.bprintf(old_buf[:], "%d", atk.damage * (1 + atk.upgrades.damage))
			new_val = fmt.bprintf(new_buf[:], "%d", atk.damage * (2 + atk.upgrades.damage))
		case .Projectiles:
			old_val = fmt.bprintf(old_buf[:], "%d", 1 + atk.upgrades.projectiles)
			new_val = fmt.bprintf(new_buf[:], "%d", 2 + atk.upgrades.projectiles)
		case .Reach:
			if cfg, cfg_ok := atk.attack_type.(Melee_Config); cfg_ok {
				old_reach := cfg.length + f32(atk.upgrades.reach) * REACH_PER_UPGRADE
				new_reach := old_reach + REACH_PER_UPGRADE
				old_val = fmt.bprintf(old_buf[:], "%.0f", old_reach)
				new_val = fmt.bprintf(new_buf[:], "%.0f", new_reach)
			}
		case .Cooldown:
			old_cd := attack_effective_interval(atk)
			new_cd := max(MIN_INTERVAL, old_cd - COOLDOWN_REDUCTION_PER_UPGRADE)
			old_val = fmt.bprintf(old_buf[:], "%.1fs", old_cd)
			new_val = fmt.bprintf(new_buf[:], "%.1fs", new_cd)
		}

		label := fmt.bprintf(
			label_bufs[i][:],
			"%s\n%s\n%s -> %s",
			atk.name,
			upgrade_type_name(opt.upgrade_type),
			old_val,
			new_val,
		)
		items[i] = Menu_Item {
			label = label,
		}
	}

	def := Menu_Def {
		label       = "LEVEL UP!",
		layout      = .Horizontal,
		items       = items[:gd.level_up_count],
		style       = CARD_STYLE,
		interaction = MENU_INTERACT_NO_SCROLL,
	}
	center := rl.Vector2{f32(SCREEN_WIDTH) / 2, f32(SCREEN_HEIGHT) / 2}
	result := draw_menu(def, &gd.menu_nav, center)

	if result >= 0 && result < gd.level_up_count {
		opt := gd.level_up_options[result]
		atk := &gd.player.attacks[opt.attack_idx]
		switch opt.upgrade_type {
		case .Damage:
			atk.upgrades.damage += 1
		case .Projectiles:
			atk.upgrades.projectiles += 1
		case .Reach:
			atk.upgrades.reach += 1
		case .Cooldown:
			atk.upgrades.cooldown += 1
		}
		gd.state = .Playing
		gd.menu_nav = menu_nav_open()
	}
}
