package main

import "core:fmt"
import "core:math"
import rl "vendor:raylib"

Player :: struct {
	sprite:       rl.Texture2D,
	attacks:      [dynamic]Attack,
	name:         string,
	loc:          rl.Vector2,
	velocity:     rl.Vector2,
	health:       i32,
	speed:        f32,
	acceleration: f32,
	friction:     f32,
	scale:        f32,
	movedir:      Move_Dir,
	score:        u32,
	posted_score: bool,
	is_dodging:   bool,
	dodge_timer:  f32,
	dodge_dir:    rl.Vector2,
}

player_init :: proc(sprite: rl.Texture2D) -> Player {
	p := Player {
		sprite  = sprite,
		attacks = make([dynamic]Attack, 0, 10),
	}
	player_apply_defaults(&p)
	return p
}

player_deinit :: proc(p: ^Player) {
	delete(p.attacks)
}

player_apply_defaults :: proc(p: ^Player) {
	p.name = "Player"
	p.loc = {150, 150}
	p.velocity = {0, 0}
	p.health = 5
	p.speed = 5.0
	p.acceleration = 10.0
	p.friction = 15.0
	p.scale = 2.0
	p.movedir = .None
	p.score = 0
	p.posted_score = false
	p.is_dodging = false
	p.dodge_timer = 0
	p.dodge_dir = {0, 0}

	clear(&p.attacks)
	append(
		&p.attacks,
		make_attack(
			"Sweep",
			Melee_Config {
				style = .Sweep,
				width = 4.0,
				length = 40.0,
				sweep_radius = math.PI,
				duration = 0.35,
			},
			2,
			1.0,
		),
		make_attack("PewPew", Projectile_Config{speed = 500, radius = 3}, 1, 1.0),
	)
}

player_reset :: proc(p: ^Player) {
	player_apply_defaults(p)
}

player_take_damage :: proc(p: ^Player, damage: i32) {
	p.health -= damage
}

player_get_area :: proc(p: ^Player) -> rl.Rectangle {
	w := f32(p.sprite.width)
	h := f32(p.sprite.height)
	return {p.loc.x, p.loc.y, w * p.scale, h * p.scale}
}

player_get_center :: proc(p: ^Player) -> rl.Vector2 {
	area := player_get_area(p)
	return {area.x + area.width / 2, area.y + area.height / 2}
}

player_dash :: proc(p: ^Player, target: rl.Vector2) {
	if !p.is_dodging && (rl.IsKeyPressed(.SPACE) || rl.IsKeyPressed(.BACKSPACE)) {
		p.is_dodging = true
		p.dodge_timer = 0.2

		center := player_get_center(p)
		p.dodge_dir = target - center

		length := rl.Vector2Length(p.dodge_dir)
		if length > 0 {
			p.dodge_dir /= length
		} else {
			p.dodge_dir = {1, 0}
		}
	}
}

player_movement :: proc(
	p: ^Player,
	gd: ^Game_Data,
	obstacles: []rl.Rectangle,
	bounds: rl.Rectangle,
) {
	dt := rl.GetFrameTime()

	// Gather input direction
	input_dir: rl.Vector2
	is_moving := false

	if rl.IsKeyDown(.RIGHT) || rl.IsKeyDown(.D) {
		input_dir.x += 1
		p.movedir = .Right
		is_moving = true
	}
	if rl.IsKeyDown(.LEFT) || rl.IsKeyDown(.A) {
		input_dir.x -= 1
		p.movedir = .Left
		is_moving = true
	}
	if rl.IsKeyDown(.UP) || rl.IsKeyDown(.W) {
		input_dir.y -= 1
		p.movedir = .Up
		is_moving = true
	}
	if rl.IsKeyDown(.DOWN) || rl.IsKeyDown(.S) {
		input_dir.y += 1
		p.movedir = .Down
		is_moving = true
	}

	// Desired velocity
	desired_vel: rl.Vector2
	if is_moving {
		length := rl.Vector2Length(input_dir)
		if length > 0 {
			input_dir /= length
		}
		max_speed := p.speed * 60
		desired_vel = input_dir * max_speed
	} else if rl.Vector2Length(p.velocity) < 10 && !p.is_dodging {
		p.movedir = .None
	}

	// Acceleration/friction rate
	accel_rate := p.acceleration if is_moving else p.friction

	// Apply dodge force
	if p.is_dodging {
		dodge_power := p.speed * 120 * (p.dodge_timer / 0.2)
		p.velocity += p.dodge_dir * dodge_power * dt
		accel_rate *= 0.1
		p.dodge_timer -= dt
		if p.dodge_timer <= 0 {
			p.is_dodging = false
		}
	}

	// Lerp velocity
	p.velocity.x = math.lerp(p.velocity.x, desired_vel.x, accel_rate * dt)
	p.velocity.y = math.lerp(p.velocity.y, desired_vel.y, accel_rate * dt)

	// Cap speed
	current_speed := rl.Vector2Length(p.velocity)
	max_speed := p.speed * 60
	if current_speed > max_speed && !p.is_dodging {
		p.velocity = (p.velocity / current_speed) * max_speed
	}

	// Friction when not pressing keys
	if !is_moving && rl.Vector2Length(p.velocity) > 0.1 && !p.is_dodging {
		vel_len := rl.Vector2Length(p.velocity)
		friction_force := p.friction * dt
		new_vel_len := max(f32(0), vel_len - friction_force)
		if vel_len > 0 {
			p.velocity = (p.velocity / vel_len) * new_vel_len
		}
	} else if !is_moving && rl.Vector2Length(p.velocity) <= 0.1 && !p.is_dodging {
		p.velocity = {0, 0}
	}

	// Apply movement with collision (X then Y for sliding)
	move_x := p.velocity.x * dt
	move_y := p.velocity.y * dt

	rect_x := player_get_area(p)
	rect_x.x += move_x
	rect_y := player_get_area(p)
	rect_y.y += move_y

	hit_x := false
	hit_y := false

	// Check obstacles
	for obs in obstacles {
		if !hit_x && rl.CheckCollisionRecs(rect_x, obs) {hit_x = true}
		if !hit_y && rl.CheckCollisionRecs(rect_y, obs) {hit_y = true}
		if hit_x && hit_y {break}
	}

	// Check enemies
	if !hit_x || !hit_y {
		for &enemy in gd.enemies {
			enemy_rect := enemy_get_area(&enemy)
			if !hit_x && rl.CheckCollisionRecs(rect_x, enemy_rect) {hit_x = true}
			if !hit_y && rl.CheckCollisionRecs(rect_y, enemy_rect) {hit_y = true}
			if hit_x && hit_y {break}
		}
	}

	if hit_x {
		p.velocity.x = 0
	} else {
		p.loc.x += move_x
	}

	if hit_y {
		p.velocity.y = 0
	} else {
		p.loc.y += move_y
	}

	// Clamp to map
	p_width := rect_x.width
	p_height := rect_x.height
	p.loc.x = clamp(p.loc.x, bounds.x, bounds.width - p_width)
	p.loc.y = clamp(p.loc.y, bounds.y, bounds.height - p_height)
}

player_draw :: proc(p: ^Player) {
	rl.DrawTextureEx(p.sprite, p.loc, 0, p.scale, rl.WHITE)
	when SHOW_DEBUG {
		rl.DrawRectangleLinesEx(player_get_area(p), 1, rl.RED)
	}
}

player_update :: proc(
	p: ^Player,
	gd: ^Game_Data,
	obstacles: []rl.Rectangle,
	target: rl.Vector2,
	bounds: rl.Rectangle,
) {
	player_movement(p, gd, obstacles, bounds)

	for &atk in p.attacks {
		if attack_tick(&atk) {
			switch cfg in atk.attack_type {
			case Melee_Config:
				reach := cfg.length + f32(atk.upgrades.reach) * REACH_PER_UPGRADE
				dmg := atk.damage * (1 + atk.upgrades.damage)
				m := melee_new_with_params(
					p,
					target,
					dmg,
					cfg.style,
					cfg.width,
					reach,
					cfg.duration,
					cfg.sweep_radius,
				)
				append(&gd.melee_attacks, m)

			case Projectile_Config:
				count := 1 + int(atk.upgrades.projectiles)
				dmg := atk.damage * (1 + atk.upgrades.damage)

				for i in 0 ..< count {
					proj := projectile_new(p, target, dmg, cfg.speed)
					if atk.upgrades.damage > 0 {
						proj.glow = true
					}

					// Spread extra projectiles perpendicular to the firing direction
					if i > 0 {
						spacing: f32 = 20
						// Alternate sides: i=1 -> +1, i=2 -> -1, i=3 -> +2, i=4 -> -2, ...
						side := i32(1) if i % 2 != 0 else i32(-1)
						offset := f32((i + 1) / 2) * spacing * f32(side)
						vel_len := rl.Vector2Length(proj.velocity)
						if vel_len > 0 {
							perp_x := proj.velocity.y / vel_len
							perp_y := -proj.velocity.x / vel_len
							proj.curloc.x += perp_x * offset
							proj.curloc.y += perp_y * offset
						}
					}
					append(&gd.projectiles, proj)
				}
			}
		}
	}
}
