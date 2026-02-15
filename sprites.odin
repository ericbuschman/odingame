package main

import rl "vendor:raylib"
import "core:strings"
import "core:fmt"

load_sprite :: proc(name: string) -> rl.Texture2D {
	buf: [256]byte
	path := fmt.bprintf(buf[:], "resources/sprites/sprite_%s.png\x00", name)
	cpath := cstring(raw_data(path))
	tex := rl.LoadTexture(cpath)
	if tex.id == 0 {
		// Fallback: try generic names
		if strings.has_prefix(name, "grass") {
			return load_sprite("grass_0")
		}
		if name == "dirt" {
			return load_sprite("dirt_0")
		}
		fmt.eprintln("Failed to load sprite:", name)
	}
	return tex
}
