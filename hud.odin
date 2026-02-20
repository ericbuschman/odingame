package main

import rl "vendor:raylib"

draw_hud :: proc(heart_tex: rl.Texture2D, hp: i32, camera: ^rl.Camera2D) {
	if hp <= 0 {return}

	screen_loc := rl.GetScreenToWorld2D({10, 0}, camera^)

	for i in 0 ..< hp {
		offset := f32(i)
		pos := rl.Vector2{screen_loc.x + offset * 20, screen_loc.y + 10}
		rl.DrawTextureEx(heart_tex, pos, 0, 1, rl.RED)
	}
}
