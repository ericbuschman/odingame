package main

import rl "vendor:raylib"

Entity :: union {
	^Player,
	^Enemy,
}

entity_get_area :: proc(e: Entity) -> rl.Rectangle {
	switch v in e {
	case ^Player:
		return player_get_area(v)
	case ^Enemy:
		return enemy_get_area(v)
	}
	return {}
}

entity_get_center :: proc(e: Entity) -> rl.Vector2 {
	area := entity_get_area(e)
	return {area.x + area.width / 2, area.y + area.height / 2}
}

entity_same :: proc(a, b: Entity) -> bool {
	switch pa in a {
	case ^Player:
		if pb, ok := b.(^Player); ok {return pa == pb}
	case ^Enemy:
		if pb, ok := b.(^Enemy); ok {return pa == pb}
	}
	return false
}
