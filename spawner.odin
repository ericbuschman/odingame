package main

import rl "vendor:raylib"

Spawn_Request :: struct {
	parent: Entity,
	target: rl.Vector2,
	damage: i32,
	speed:  f32,
}
