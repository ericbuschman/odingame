package main

import "core:encoding/json"
import "core:fmt"
import "core:os"
import "core:strings"
import rl "vendor:raylib"

Tile :: struct {
	rect:    rl.Rectangle,
	texture: rl.Texture2D,
}

Game_Map :: struct {
	width:        i32,
	height:       i32,
	tile_size:    f32,
	tiles:        [dynamic]Tile,
	obstructions: [dynamic]rl.Rectangle,
	textures:     map[string]rl.Texture2D,
}

// JSON structures
Map_Metadata :: struct {
	width:        i32   `json:"width"`,
	height:       i32   `json:"height"`,
	tileSize:     i32   `json:"tileSize"`,
	lastModified: string `json:"lastModified"`,
}

Tile_Data :: struct {
	x:    f32    `json:"x"`,
	y:    f32    `json:"y"`,
	type: string `json:"type"`,
}

Tiles_Container :: struct {
	floor: []Tile_Data `json:"floor"`,
}

Obstruction_Data :: struct {
	x:      f32    `json:"x"`,
	y:      f32    `json:"y"`,
	type:   string `json:"type"`,
	width:  f32    `json:"width"`,
	height: f32    `json:"height"`,
}

Map_Json :: struct {
	version:      string            `json:"version"`,
	metadata:     Map_Metadata      `json:"metadata"`,
	tiles:        Tiles_Container   `json:"tiles"`,
	obstructions: []Obstruction_Data `json:"obstructions"`,
}

game_map_init :: proc(path: string, scale: f32) -> (Game_Map, bool) {
	data, ok := os.read_entire_file(path)
	if !ok {
		fmt.eprintln("Failed to read map file:", path)
		return {}, false
	}
	defer delete(data)

	map_data: Map_Json
	err := json.unmarshal(data, &map_data)
	if err != nil {
		fmt.eprintln("Failed to parse map JSON:", err)
		return {}, false
	}
	defer {
		delete(map_data.tiles.floor)
		delete(map_data.obstructions)
	}

	gm := Game_Map {
		width     = map_data.metadata.width / map_data.metadata.tileSize,
		height    = map_data.metadata.height / map_data.metadata.tileSize,
		tile_size = f32(map_data.metadata.tileSize) * scale,
		tiles     = make([dynamic]Tile, 0, len(map_data.tiles.floor)),
		obstructions = make([dynamic]rl.Rectangle, 0, len(map_data.obstructions)),
		textures  = make(map[string]rl.Texture2D),
	}

	// Load floor tiles
	for td in map_data.tiles.floor {
		tex := game_map_get_texture(&gm, td.type)
		append(&gm.tiles, Tile {
			rect = {td.x * scale, td.y * scale, gm.tile_size, gm.tile_size},
			texture = tex,
		})
	}

	// Load obstructions
	for od in map_data.obstructions {
		append(&gm.obstructions, rl.Rectangle {
			od.x * scale,
			od.y * scale,
			od.width * scale,
			od.height * scale,
		})
	}

	return gm, true
}

game_map_deinit :: proc(gm: ^Game_Map) {
	delete(gm.tiles)
	delete(gm.obstructions)
	for key, tex in gm.textures {
		rl.UnloadTexture(tex)
		delete(key)
	}
	delete(gm.textures)
}

game_map_get_texture :: proc(gm: ^Game_Map, type_name: string) -> rl.Texture2D {
	if tex, found := gm.textures[type_name]; found {
		return tex
	}

	tex := load_sprite(type_name)
	key := strings.clone(type_name)
	gm.textures[key] = tex
	return tex
}

game_map_draw :: proc(gm: ^Game_Map, camera: rl.Camera2D) {
	sw := f32(rl.GetScreenWidth())
	sh := f32(rl.GetScreenHeight())

	top_left := rl.GetScreenToWorld2D({0, 0}, camera)
	bottom_right := rl.GetScreenToWorld2D({sw, sh}, camera)

	visible := rl.Rectangle {
		top_left.x - gm.tile_size,
		top_left.y - gm.tile_size,
		(bottom_right.x - top_left.x) + gm.tile_size * 2,
		(bottom_right.y - top_left.y) + gm.tile_size * 2,
	}

	for tile in gm.tiles {
		if rl.CheckCollisionRecs(visible, tile.rect) {
			source := rl.Rectangle {0, 0, f32(tile.texture.width), f32(tile.texture.height)}
			rl.DrawTexturePro(tile.texture, source, tile.rect, {0, 0}, 0, rl.WHITE)
		}
	}
}
