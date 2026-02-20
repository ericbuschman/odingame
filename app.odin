package main

import "core:encoding/json"
import "core:fmt"
import "core:os"
import rl "vendor:raylib"

App_State :: enum {
	Main_Menu,
	Settings,
	Playing,
	Quitting,
}

App_Settings :: struct {
	master_volume: f32,
	fullscreen:    bool,
}

App :: struct {
	state:    App_State,
	game:     Maybe(Game),
	settings: App_Settings,
	menu_nav: Menu_Nav,
}

SETTINGS_PATH :: "settings.json"

Settings_Json :: struct {
	master_volume: f32 `json:"master_volume"`,
	fullscreen:    bool `json:"fullscreen"`,
}

settings_load :: proc() -> App_Settings {
	data, ok := os.read_entire_file(SETTINGS_PATH)
	if !ok {
		return App_Settings{master_volume = 0.8, fullscreen = false}
	}
	defer delete(data)

	sj: Settings_Json
	err := json.unmarshal(data, &sj)
	if err != nil {
		fmt.eprintln("Failed to parse settings:", err)
		return App_Settings{master_volume = 0.8, fullscreen = false}
	}

	return App_Settings{master_volume = clamp(sj.master_volume, 0, 1), fullscreen = sj.fullscreen}
}

settings_save :: proc(s: App_Settings) {
	sj := Settings_Json {
		master_volume = s.master_volume,
		fullscreen    = s.fullscreen,
	}

	data, err := json.marshal(sj)
	if err != nil {
		fmt.eprintln("Failed to marshal settings:", err)
		return
	}
	defer delete(data)

	os.write_entire_file(SETTINGS_PATH, data)
}

settings_apply :: proc(s: App_Settings) {
	rl.SetMasterVolume(s.master_volume)
}
