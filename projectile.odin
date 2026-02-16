package main

import "core:math"
import rl "vendor:raylib"

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
		curloc = start_loc,
		velocity = vel,
		radius = 3,
		color = rl.WHITE,
		glow = false,
		damage = damage,
		active = true,
		parent = parent,
	}
}

projectile_check_collision :: proc(proj: ^Projectile, other: Entity) -> bool {
	if entity_same(proj.parent, other) {return false}
	return rl.CheckCollisionCircleRec(proj.curloc, proj.radius, entity_get_area(other))
}

projectile_move :: proc(proj: ^Projectile, camera: rl.Camera2D, bounds: rl.Rectangle) {
	dt := rl.GetFrameTime()
	proj.curloc += proj.velocity * dt

	if !is_on_screen(proj.curloc, camera) || !is_in_bounds(proj.curloc, bounds) {
		proj.active = false
	}
}

projectile_draw :: proc(proj: ^Projectile) {
	if !proj.active {return}
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
