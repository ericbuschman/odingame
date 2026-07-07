package main

import "core:encoding/json"
import "core:fmt"
import "core:os"
import "core:strings"
import rl "vendor:raylib"

Tile :: struct {
	rect:        rl.Rectangle,
	region_name: string,
}

Game_Map :: struct {
	width:        i32,
	height:       i32,
	tile_size:    f32,
	tiles:        [dynamic]Tile,
	obstructions: [dynamic]rl.Rectangle,
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
	data, read_err := os.read_entire_file_from_path(path, context.allocator)
	if read_err != nil {
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
	}

	// Load floor tiles
	for td in map_data.tiles.floor {
		append(&gm.tiles, Tile {
			rect = {td.x * scale, td.y * scale, gm.tile_size, gm.tile_size},
			region_name = strings.clone(td.type),
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
	for t in gm.tiles {
		delete(t.region_name)
	}
	delete(gm.tiles)
	delete(gm.obstructions)
}

game_map_draw :: proc(gm: ^Game_Map, atlas: ^Sprite_Atlas, camera: rl.Camera2D) {
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
			if source, found := atlas.statics[tile.region_name]; found {
				if tex, tex_found := atlas.textures[source.texture_key]; tex_found {
					rl.DrawTexturePro(tex, source.rect, tile.rect, {0, 0}, 0, rl.WHITE)
				}
			}
		}
	}
}
