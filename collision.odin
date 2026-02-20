package main

import rl "vendor:raylib"

resolve_projectile_collisions :: proc(gd: ^Game_Data, obstructions: []rl.Rectangle) {
	for i := 0; i < len(gd.projectiles); {
		proj := &gd.projectiles[i]

		// Obstruction collisions
		for b in obstructions {
			if rl.CheckCollisionCircleRec(proj.curloc, proj.radius, b) {
				proj.active = false
				particle_emit_collision(&gd.particles, proj.curloc, rl.GRAY)
				break
			}
		}

		// Enemy collisions (player-owned projectiles)
		for &enemy in gd.enemies {
			if projectile_check_collision(proj, &enemy) {
				_, is_player := proj.parent.(^Player)
				if is_player {
					particle_emit_collision(&gd.particles, proj.curloc, rl.ORANGE)
					enemy_take_damage(&enemy, proj.damage)
					proj.active = false
				}
			}
		}

		// Player collision (enemy-owned projectiles)
		if projectile_check_collision(proj, &gd.player) {
			player_take_damage(&gd.player, proj.damage)
			if gd.player.health <= 0 {
				gd.state = .Game_Over
				gd.menu_nav = menu_nav_open()
			} else {
				particle_emit_collision(&gd.particles, proj.curloc, rl.RED)
			}
			proj.active = false
		}

		if !proj.active {
			unordered_remove(&gd.projectiles, i)
		} else {
			i += 1
		}
	}
}

resolve_melee_collisions :: proc(gd: ^Game_Data) {
	for i := 0; i < len(gd.melee_attacks); {
		atk := &gd.melee_attacks[i]

		// Enemy collisions (player-owned melee)
		for &en in gd.enemies {
			if melee_check_collision(atk, &en) {
				_, is_player := atk.parent.(^Player)
				if is_player {
					en_center := enemy_get_center(&en)
					particle_emit_collision(&gd.particles, en_center, rl.GREEN)
					enemy_take_damage(&en, atk.damage)
				}
			}
		}

		// Player collision (enemy-owned melee)
		if melee_check_collision(atk, &gd.player) {
			_, is_enemy := atk.parent.(^Enemy)
			if is_enemy {
				player_take_damage(&gd.player, atk.damage)
				if gd.player.health <= 0 {
					gd.state = .Game_Over
					gd.menu_nav = menu_nav_open()
				} else {
					p_center := player_get_center(&gd.player)
					particle_emit_collision(&gd.particles, p_center, rl.RED)
				}
			}
		}

		if !atk.active {
			unordered_remove(&gd.melee_attacks, i)
		} else {
			i += 1
		}
	}
}
