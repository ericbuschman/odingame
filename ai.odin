package main

import "core:math"
import rl "vendor:raylib"

move_towards :: proc(location, target: rl.Vector2, speed, delta_time, keep_distance: f32) -> rl.Vector2 {
	direction := target - location
	length := rl.Vector2Length(direction)

	eps: f32 = 5.0
	desired_stop_distance := keep_distance + eps

	if length <= desired_stop_distance {
		return location
	}

	normalized := direction / length
	movement_this_frame := speed * delta_time
	distance_to_move := min(movement_this_frame, length)

	return location + normalized * distance_to_move
}

move_away :: proc(location, target: rl.Vector2, speed, delta_time: f32) -> rl.Vector2 {
	direction := location - target
	length := rl.Vector2Length(direction)

	if length <= 0 {
		return location
	}

	normalized := direction / length
	movement_this_frame := speed * delta_time / 2

	return location + normalized * movement_this_frame
}
