package main

import rl "vendor:raylib"

SCREEN_WIDTH :: 1024
SCREEN_HEIGHT :: 768
MID_WIDTH :: SCREEN_WIDTH / 2
MID_HEIGHT :: SCREEN_HEIGHT / 2
STEP_SIZE :: 16
PLAYER_WIDTH :: 25
PLAYER_HEIGHT :: 25
SHOW_DEBUG :: false
DEBUG_NO_ENEMIES :: false

map_width: f32 = 32000.0
map_height: f32 = 32000.0
play_area: rl.Rectangle = {0, 0, 32000, 32000}
