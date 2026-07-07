package main

import "core:math"
import rl "vendor:raylib"

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

Upgrade_Type :: enum {
	Damage,
	Projectiles, // ranged only
	Reach,       // melee only
	Cooldown,
}

MAX_UPGRADES_PER_ATTACK :: i32(5)
COOLDOWN_REDUCTION_PER_UPGRADE :: f32(0.1) // seconds per upgrade
MIN_INTERVAL :: f32(0.1)
REACH_PER_UPGRADE :: f32(15.0)

Attack_Upgrades :: struct {
	damage:      i32,
	projectiles: i32,
	reach:       i32,
	cooldown:    i32,
}

Attack :: struct {
	name:               cstring,
	attack_type:        Attack_Type,
	damage:             i32,
	interval:           f32,
	remaining_interval: f32,
	upgrades:           Attack_Upgrades,
	weapon_tex_idx:     int,
}

make_attack :: proc(
	name: cstring,
	attack_type: Attack_Type,
	damage: i32,
	interval: f32,
	weapon_tex_idx := 0,
) -> Attack {
	return Attack {
		name = name,
		attack_type = attack_type,
		damage = damage,
		interval = interval,
		remaining_interval = interval,
		weapon_tex_idx = weapon_tex_idx,
	}
}

attack_total_upgrades :: proc(atk: ^Attack) -> i32 {
	u := atk.upgrades
	return u.damage + u.projectiles + u.reach + u.cooldown
}

attack_effective_interval :: proc(atk: ^Attack) -> f32 {
	reduction := f32(atk.upgrades.cooldown) * COOLDOWN_REDUCTION_PER_UPGRADE
	return max(MIN_INTERVAL, atk.interval - reduction)
}

attack_tick :: proc(atk: ^Attack) -> bool {
	atk.remaining_interval -= rl.GetFrameTime()
	if atk.remaining_interval <= 0 {
		atk.remaining_interval = attack_effective_interval(atk)
		return true
	}
	return false
}
