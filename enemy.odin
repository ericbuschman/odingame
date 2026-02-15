package main

import "core:fmt"
import rl "vendor:raylib"

Enemy_State :: enum {
	Idle,
	Towards_Player,
	Keep_Away,
	Run_Away,
}

Enemy :: struct {
	loc:         rl.Vector2,
	sprite:      rl.Texture2D,
	personality: Enemy_State,
	state:       Enemy_State,
	rotation:    f32,
	title:       string,
	speed:       f32,
	health:      i32,
	active:      bool,
	attacks:     [dynamic]Attack,
	scale:       f32,
}

enemy_new :: proc(
	loc: rl.Vector2,
	sprite: rl.Texture2D,
	title: string,
	personality: Enemy_State,
	speed: f32,
	health: i32,
) -> Enemy {
	return Enemy {
		loc         = loc,
		sprite      = sprite,
		personality = personality,
		state       = .Idle,
		rotation    = 0,
		title       = title,
		speed       = speed,
		health      = health,
		active      = true,
		attacks     = make([dynamic]Attack, 0, 4),
		scale       = 2.0,
	}
}

enemy_deinit :: proc(e: ^Enemy) {
	delete(e.attacks)
}

enemy_take_damage :: proc(e: ^Enemy, damage: i32) {
	e.health -= damage
	if e.health <= 0 {
		e.active = false
	}
}

enemy_get_area :: proc(e: ^Enemy) -> rl.Rectangle {
	w := f32(e.sprite.width) * e.scale
	h := f32(e.sprite.height) * e.scale
	return {e.loc.x - w / 2, e.loc.y - h / 2, w, h}
}

enemy_get_center :: proc(e: ^Enemy) -> rl.Vector2 {
	area := enemy_get_area(e)
	return {area.x + area.width / 2, area.y + area.height / 2}
}

enemy_movement :: proc(e: ^Enemy, p: ^Player, obstacles: []rl.Rectangle) {
	on_screen := true

	if e.state == .Idle && on_screen {
		e.state = e.personality
	}
	if !on_screen {
		e.state = .Idle
	}

	new_loc := e.loc
	player_center := player_get_center(p)
	enemy_area := enemy_get_area(e)
	player_area := player_get_area(p)

	keep_distance := (enemy_area.width / 2) + (player_area.width / 2) + 10

	switch e.state {
	case .Idle:
		// do nothing
	case .Towards_Player:
		new_loc = move_towards(e.loc, player_center, e.speed, rl.GetFrameTime(), keep_distance)
	case .Keep_Away:
		dist := rl.Vector2Distance(e.loc, player_center)
		if dist < 350 * f32(STEP_SIZE) {
			new_loc = move_away(e.loc, player_center, e.speed, rl.GetFrameTime())
		}
	case .Run_Away:
		new_loc = move_away(e.loc, player_center, e.speed * 1.5, rl.GetFrameTime())
	}

	if on_screen {
		// Try X
		original_x := e.loc.x
		e.loc.x = new_loc.x
		enemy_rect := enemy_get_area(e)
		collision := false
		for obs in obstacles {
			if rl.CheckCollisionRecs(enemy_rect, obs) {
				collision = true
				break
			}
		}
		if collision { e.loc.x = original_x }

		// Try Y
		original_y := e.loc.y
		e.loc.y = new_loc.y
		enemy_rect = enemy_get_area(e)
		collision = false
		for obs in obstacles {
			if rl.CheckCollisionRecs(enemy_rect, obs) {
				collision = true
				break
			}
		}
		if collision { e.loc.y = original_y }
	}
}

enemy_update_attacks :: proc(e: ^Enemy, target: rl.Vector2, spawn_queue: ^[dynamic]Spawn_Request) {
	for &atk in e.attacks {
		if get_attack(&atk) {
			switch cfg in atk.attack_type {
			case Melee_Config:
				// enemies don't use melee in original
			case Projectile_Config:
				append(spawn_queue, Spawn_Request {
					parent = e,
					target = target,
					damage = atk.damage,
					speed  = cfg.speed,
				})
			}
		}
	}
}

enemy_draw :: proc(e: ^Enemy) {
	w := f32(e.sprite.width) * e.scale
	h := f32(e.sprite.height) * e.scale

	origin := rl.Vector2{w / 2, h / 2}
	source := rl.Rectangle{0, 0, f32(e.sprite.width), f32(e.sprite.height)}
	dest := rl.Rectangle{e.loc.x, e.loc.y, w, h}

	rl.DrawTexturePro(e.sprite, source, dest, origin, e.rotation, rl.WHITE)

	when SHOW_DEBUG {
		adjusted := rl.Rectangle{dest.x - origin.x, dest.y - origin.y, dest.width, dest.height}
		rl.DrawRectangleLinesEx(adjusted, 1, rl.RED)
	}
}
