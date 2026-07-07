package main

import "core:encoding/json"
import "core:fmt"
import "core:os"
import "core:strings"
import rl "vendor:raylib"

Sprite_Static :: struct {
	texture_key: string,
	rect:        rl.Rectangle,
}

Sprite_Animation :: struct {
	texture_key: string,
	rects:       []rl.Rectangle,
}

Sprite_Atlas :: struct {
	textures:   map[string]rl.Texture2D,
	statics:    map[string]Sprite_Static,
	animations: map[string]Sprite_Animation,
}

Atlas_Json_Static :: struct {
	texture_file: string `json:"texture_file"`,
	x:            f32    `json:"x"`,
	y:            f32    `json:"y"`,
	w:            f32    `json:"w"`,
	h:            f32    `json:"h"`,
}

Atlas_Json_Anim_Frame :: struct {
	x:            f32    `json:"x"`,
	y:            f32    `json:"y"`,
	w:            f32    `json:"w"`,
	h:            f32    `json:"h"`,
}

Atlas_Json_Animation :: struct {
	texture_file: string `json:"texture_file"`,
	frames:       []Atlas_Json_Anim_Frame `json:"frames"`,
}

Atlas_Json :: struct {
	static_sprites: map[string]Atlas_Json_Static    `json:"static_sprites"`,
	animations:     map[string]Atlas_Json_Animation `json:"animations"`,
}

load_sprite :: proc(name: string, scale: f32 = 1.0) -> rl.Texture2D {
	buf: [256]byte
	path := fmt.bprintf(buf[:], "resources/sprites/sprite_%s.png\x00", name)
	cpath := cstring(raw_data(path))

	img := rl.LoadImage(cpath)
	if img.width == 0 {
		// Fallback: try generic names
		if strings.has_prefix(name, "grass") {
			return load_sprite("grass_0", scale)
		}
		if name == "dirt" {
			return load_sprite("dirt_0", scale)
		}
		fmt.eprintln("Failed to load sprite image:", name)
		return {}
	}
	defer rl.UnloadImage(img)

	if scale != 1.0 {
		new_w := i32(f32(img.width) * scale)
		new_h := i32(f32(img.height) * scale)
		rl.ImageResizeNN(&img, new_w, new_h)
	}

	tex := rl.LoadTextureFromImage(img)
	if tex.id == 0 {
		fmt.eprintln("Failed to load texture from image:", name)
	}
	return tex
}

load_atlas :: proc(path: string) -> (Sprite_Atlas, bool) {
	data, read_err := os.read_entire_file_from_path(path, context.allocator)
	if read_err != nil {
		fmt.eprintln("Failed to read atlas file:", path)
		return {}, false
	}
	defer delete(data)

	atlas_json: Atlas_Json
	err := json.unmarshal(data, &atlas_json)
	if err != nil {
		fmt.eprintln("Failed to parse atlas JSON:", err)
		return {}, false
	}
	defer delete(atlas_json.static_sprites)
	
	defer {
		for _, anim in atlas_json.animations {
			delete(anim.frames)
		}
		delete(atlas_json.animations)
	}

	atlas := Sprite_Atlas {
		textures   = make(map[string]rl.Texture2D),
		statics    = make(map[string]Sprite_Static),
		animations = make(map[string]Sprite_Animation),
	}

	ensure_texture_loaded :: proc(atlas: ^Sprite_Atlas, tex_filename: string) -> bool {
		if tex_filename in atlas.textures {
			return true
		}
		tex_path := fmt.tprintf("resources/sprites/%s", tex_filename)
		cpath := cstring(raw_data(tex_path))
		tex := rl.LoadTexture(cpath)
		if tex.id == 0 {
			fmt.eprintln("Failed to load texture:", tex_path)
			return false
		}
		key := strings.clone(tex_filename)
		atlas.textures[key] = tex
		return true
	}

	for name, s_json in atlas_json.static_sprites {
		if s_json.w > 0 && s_json.h > 0 {
			if !ensure_texture_loaded(&atlas, s_json.texture_file) {
				continue
			}
			key := strings.clone(name)
			atlas.statics[key] = Sprite_Static {
				texture_key = strings.clone(s_json.texture_file),
				rect = rl.Rectangle {
					x      = s_json.x,
					y      = s_json.y,
					width  = s_json.w,
					height = s_json.h,
				},
			}
		}
	}

	for name, anim_json in atlas_json.animations {
		if !ensure_texture_loaded(&atlas, anim_json.texture_file) {
			continue
		}
		key := strings.clone(name)
		odin_rects := make([]rl.Rectangle, len(anim_json.frames))
		for r, idx in anim_json.frames {
			odin_rects[idx] = rl.Rectangle {
				x      = r.x,
				y      = r.y,
				width  = r.w,
				height = r.h,
			}
		}
		atlas.animations[key] = Sprite_Animation {
			texture_key = strings.clone(anim_json.texture_file),
			rects       = odin_rects,
		}
	}

	return atlas, true
}
