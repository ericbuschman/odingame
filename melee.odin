package main

import "core:math"
import rl "vendor:raylib"

Attack_Style :: enum {
	Sweep,
	Thrust,
}

Melee_Attack :: struct {
	parent:       Entity,
	target_angle: f32,
	style:        Attack_Style,
	damage:       i32,
	width:        f32,
	length:       f32,
	sweep_radius: f32,
	duration:     f32,
	elapsed:      f32,
	active:       bool,
}

melee_new :: proc(parent: Entity, target: rl.Vector2, damage: i32, style: Attack_Style) -> Melee_Attack {
	center := entity_get_center(parent)
	dx := target.x - center.x
	dy := target.y - center.y
	angle := math.atan2(dy, dx)

	return Melee_Attack {
		parent       = parent,
		target_angle = angle,
		style        = style,
		damage       = damage,
		width        = 4.0,
		length       = 40.0,
		sweep_radius = math.PI,
		duration     = 0.75,
		elapsed      = 0,
		active       = true,
	}
}

melee_new_with_params :: proc(
	parent: Entity,
	target: rl.Vector2,
	damage: i32,
	style: Attack_Style,
	width, length, duration, sweep_radius: f32,
) -> Melee_Attack {
	center := entity_get_center(parent)
	dx := target.x - center.x
	dy := target.y - center.y
	angle := math.atan2(dy, dx)

	return Melee_Attack {
		parent       = parent,
		target_angle = angle,
		style        = style,
		damage       = damage,
		width        = width,
		length       = length,
		sweep_radius = sweep_radius,
		duration     = duration,
		elapsed      = 0,
		active       = true,
	}
}

melee_progress :: proc(atk: ^Melee_Attack) -> f32 {
	return clamp(atk.elapsed / atk.duration, 0, 1)
}

melee_get_edge_point :: proc(atk: ^Melee_Attack, angle: f32) -> rl.Vector2 {
	area := entity_get_area(atk.parent)
	center_x := area.x + area.width / 2
	center_y := area.y + area.height / 2

	cos_a := math.cos(angle)
	sin_a := math.sin(angle)
	half_w := area.width / 2
	half_h := area.height / 2

	t_x: f32 = math.INF_F32
	t_y: f32 = math.INF_F32

	if cos_a != 0 { t_x = half_w / abs(cos_a) }
	if sin_a != 0 { t_y = half_h / abs(sin_a) }

	t := min(t_x, t_y)

	return {center_x + cos_a * t, center_y + sin_a * t}
}

melee_check_collision :: proc(atk: ^Melee_Attack, other: Entity) -> bool {
	if !atk.active { return false }

	// Don't hit parent
	switch p in atk.parent {
	case ^Player:
		switch o in other {
		case ^Player: if p == o { return false }
		case ^Enemy:
		}
	case ^Enemy:
		switch o in other {
		case ^Enemy: if p == o { return false }
		case ^Player:
		}
	}

	t := melee_progress(atk)
	other_area := entity_get_area(other)

	STEPS :: 8
	switch atk.style {
	case .Sweep:
		half_sweep := atk.sweep_radius / 2
		current_angle := atk.target_angle - half_sweep + (atk.sweep_radius * t)
		start := melee_get_edge_point(atk, current_angle)
		end_pt := rl.Vector2 {
			start.x + math.cos(current_angle) * atk.length,
			start.y + math.sin(current_angle) * atk.length,
		}
		for s in 0 ..= STEPS {
			frac := f32(s) / f32(STEPS)
			px := start.x + (end_pt.x - start.x) * frac
			py := start.y + (end_pt.y - start.y) * frac
			if rl.CheckCollisionPointRec({px, py}, other_area) {
				return true
			}
		}

	case .Thrust:
		current_length := atk.length * t
		start := melee_get_edge_point(atk, atk.target_angle)
		end_pt := rl.Vector2 {
			start.x + math.cos(atk.target_angle) * current_length,
			start.y + math.sin(atk.target_angle) * current_length,
		}
		for s in 0 ..= STEPS {
			frac := f32(s) / f32(STEPS)
			px := start.x + (end_pt.x - start.x) * frac
			py := start.y + (end_pt.y - start.y) * frac
			if rl.CheckCollisionPointRec({px, py}, other_area) {
				return true
			}
		}
	}

	return false
}

melee_update :: proc(atk: ^Melee_Attack) {
	if !atk.active { return }
	atk.elapsed += rl.GetFrameTime()
	if atk.elapsed >= atk.duration {
		atk.active = false
	}
}

melee_draw :: proc(atk: ^Melee_Attack) {
	if !atk.active { return }

	t := melee_progress(atk)

	glow_pulse := (math.sin(t * math.PI * 4) + 1) / 2
	glow_alpha := 0.3 + glow_pulse * 0.4
	glow_color := rl.Fade(rl.GREEN, f32(glow_alpha))
	line_color := rl.WHITE

	switch atk.style {
	case .Sweep:
		half_sweep := atk.sweep_radius / 2
		current_angle := atk.target_angle - half_sweep + (atk.sweep_radius * t)
		start := melee_get_edge_point(atk, current_angle)
		end_pt := rl.Vector2 {
			start.x + math.cos(current_angle) * atk.length,
			start.y + math.sin(current_angle) * atk.length,
		}
		rl.DrawLineEx(start, end_pt, atk.width * 3, glow_color)
		rl.DrawLineEx(start, end_pt, atk.width, line_color)

	case .Thrust:
		current_length := atk.length * t
		start := melee_get_edge_point(atk, atk.target_angle)
		end_pt := rl.Vector2 {
			start.x + math.cos(atk.target_angle) * current_length,
			start.y + math.sin(atk.target_angle) * current_length,
		}
		rl.DrawLineEx(start, end_pt, atk.width * 3, glow_color)
		rl.DrawLineEx(start, end_pt, atk.width, line_color)
	}

	melee_update(atk)
}
