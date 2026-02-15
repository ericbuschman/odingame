package main

import "core:math"
import rl "vendor:raylib"

Entity :: union {
	^Player,
	^Enemy,
}

entity_get_area :: proc(e: Entity) -> rl.Rectangle {
	switch v in e {
	case ^Player:
		return player_get_area(v)
	case ^Enemy:
		return enemy_get_area(v)
	}
	return {}
}

entity_get_center :: proc(e: Entity) -> rl.Vector2 {
	area := entity_get_area(e)
	return {area.x + area.width / 2, area.y + area.height / 2}
}

Projectile :: struct {
	curloc:   rl.Vector2,
	velocity: rl.Vector2,
	radius:   f32,
	color:    rl.Color,
	glow:     bool,
	damage:   i32,
	active:   bool,
	parent:   Entity,
}

projectile_new :: proc(parent: Entity, target: rl.Vector2, damage: i32, speed: f32) -> Projectile {
	start_loc := get_projectile_start_point(entity_get_area(parent), target)
	dir := target - start_loc
	length := rl.Vector2Length(dir)

	vel: rl.Vector2
	if length != 0 {
		vel = dir / length * speed
	}

	return Projectile {
		curloc   = start_loc,
		velocity = vel,
		radius   = 3,
		color    = rl.WHITE,
		glow     = false,
		damage   = damage,
		active   = true,
		parent   = parent,
	}
}

projectile_check_collision :: proc(proj: ^Projectile, other: Entity) -> bool {
	// Don't hit parent
	is_same: bool
	switch p in proj.parent {
	case ^Player:
		switch o in other {
		case ^Player:  is_same = p == o
		case ^Enemy:   is_same = false
		}
	case ^Enemy:
		switch o in other {
		case ^Enemy:   is_same = p == o
		case ^Player:  is_same = false
		}
	}
	if is_same { return false }

	return rl.CheckCollisionCircleRec(proj.curloc, proj.radius, entity_get_area(other))
}

projectile_move :: proc(proj: ^Projectile, camera: rl.Camera2D) {
	dt := rl.GetFrameTime()
	proj.curloc += proj.velocity * dt

	if !is_on_screen(proj.curloc, camera) || !is_in_bounds(proj.curloc) {
		proj.active = false
	}
}

projectile_draw :: proc(proj: ^Projectile, camera: rl.Camera2D) {
	if proj.active {
		if proj.glow {
			rl.DrawCircleGradient(
				i32(proj.curloc.x),
				i32(proj.curloc.y),
				proj.radius * 4.0,
				rl.Fade(rl.RED, 0.8),
				rl.Fade(rl.RED, 0.0),
			)
		}
		rl.DrawCircleV(proj.curloc, proj.radius, proj.color)
	}
	projectile_move(proj, camera)
}

get_projectile_start_point :: proc(rect: rl.Rectangle, target: rl.Vector2) -> rl.Vector2 {
	center_x := rect.x + rect.width / 2
	center_y := rect.y + rect.height / 2

	dx := target.x - center_x
	dy := target.y - center_y

	if dx == 0 && dy == 0 {
		return {center_x, center_y}
	}

	half_w := rect.width / 2
	half_h := rect.height / 2

	t_x: f32 = math.INF_F32
	t_y: f32 = math.INF_F32

	if dx != 0 {
		t_x = half_w / abs(dx)
	}
	if dy != 0 {
		t_y = half_h / abs(dy)
	}

	t := min(t_x, t_y)

	return {center_x + dx * t, center_y + dy * t}
}
