package main

import "core:math"
import rl "vendor:raylib"

Attack_Upgrade :: enum {
	None,
	Damage,
	Proj_Count,
}

Projectile_Config :: struct {
	speed:  f32,
	radius: f32,
}

Melee_Config :: struct {
	style:        Attack_Style,
	width:        f32,
	length:       f32,
	sweep_radius: f32,
	duration:     f32,
}

DEFAULT_MELEE_CONFIG :: Melee_Config {
	style        = .Thrust,
	width        = 4.0,
	length       = 40.0,
	sweep_radius = math.PI,
	duration     = 0.75,
}

Attack_Type :: union {
	Melee_Config,
	Projectile_Config,
}

Attack :: struct {
	name:               cstring,
	attack_type:        Attack_Type,
	damage:             i32,
	interval:           f32,
	remaining_interval: f32,
}

make_attack :: proc(
	name: cstring,
	attack_type: Attack_Type,
	damage: i32,
	interval: f32,
) -> Attack {
	return Attack {
		name = name,
		attack_type = attack_type,
		damage = damage,
		interval = interval,
		remaining_interval = interval,
	}
}

attack_tick :: proc(atk: ^Attack) -> bool {
	atk.remaining_interval -= rl.GetFrameTime()
	if atk.remaining_interval <= 0 {
		atk.remaining_interval = atk.interval
		return true
	}
	return false
}
