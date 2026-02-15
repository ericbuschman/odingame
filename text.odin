package main

import "core:fmt"
import "core:strings"
import rl "vendor:raylib"

print_centered_text :: proc(text: string, camera: rl.Camera2D, offset_y: i32) {
	font_size: i32 = 20
	line_spacing: i32 = 2
	padding: i32 = 10

	max_width := SCREEN_WIDTH - 80 - padding * 2

	// Word wrap
	wrapped_buf: [4096]byte
	wrapped, ok := word_wrap(text, wrapped_buf[:], max_width, font_size)
	if !ok { return }

	// Calculate dimensions
	max_text_width: i32 = 0
	num_lines: i32 = 0

	// First pass: measure
	{
		tmp := wrapped
		for line in strings.split_lines_iterator(&tmp) {
			c_line := fmt.ctprintf("%s", line)
			w := rl.MeasureText(c_line, font_size)
			if w > max_text_width { max_text_width = w }
			num_lines += 1
		}
	}

	if num_lines == 0 { return }

	text_block_height := num_lines * font_size + (num_lines - 1) * line_spacing
	box_width := max_text_width + padding * 2
	box_height := text_block_height + padding * 2

	center_x := i32(camera.target.x)
	start_y := i32(camera.target.y) + offset_y

	box_x := center_x - box_width / 2
	box_y := start_y - padding

	draw_border(box_x, box_y, box_width, box_height)

	// Second pass: draw
	current_y := start_y
	{
		tmp := wrapped
		for line in strings.split_lines_iterator(&tmp) {
			c_line := fmt.ctprintf("%s", line)
			text_width := rl.MeasureText(c_line, font_size)
			x := center_x - text_width / 2
			rl.DrawText(c_line, x, current_y, font_size, rl.WHITE)
			current_y += font_size + line_spacing
		}
	}
}

draw_border :: proc(x, y, width, height: i32) {
	pad: i32 = 10
	nx := x - pad
	ny := y - pad
	nw := width + pad * 2
	nh := height + pad * 2
	border_gap: i32 = 3

	bg_color := rl.Color{15, 15, 15, 245}
	rl.DrawRectangle(nx, ny, nw, nh, bg_color)
	rl.DrawRectangleLines(nx, ny, nw, nh, rl.WHITE)
	rl.DrawRectangleLines(nx + border_gap, ny + border_gap, nw - border_gap * 2, nh - border_gap * 2, rl.WHITE)
}

word_wrap :: proc(text: string, dest: []byte, max_width, font_size: i32) -> (string, bool) {
	if len(dest) == 0 { return "", false }

	space_width := rl.MeasureText(" ", font_size)

	dest_idx := 0
	current_line_width: i32 = 0
	i := 0

	for i < len(text) {
		// Find end of current word
		word_end := i
		for word_end < len(text) && text[word_end] != ' ' && text[word_end] != '\n' {
			word_end += 1
		}

		word := text[i:word_end]
		c_word := fmt.ctprintf("%s", word)
		word_width := rl.MeasureText(c_word, font_size)

		prefix_width: i32 = 0
		if current_line_width > 0 {
			prefix_width = space_width
		}

		should_wrap := false
		if current_line_width + prefix_width + word_width > max_width && current_line_width > 0 {
			should_wrap = true
		}

		if should_wrap {
			if dest_idx < len(dest) {
				dest[dest_idx] = '\n'
				dest_idx += 1
			}
			current_line_width = 0
		} else if current_line_width > 0 {
			if dest_idx < len(dest) {
				dest[dest_idx] = ' '
				dest_idx += 1
			}
			current_line_width += space_width
		}

		// Add word
		word_len := len(word)
		if dest_idx + word_len <= len(dest) {
			copy(dest[dest_idx:], word)
			dest_idx += word_len
		}
		current_line_width += word_width

		// Handle separator
		if word_end < len(text) {
			if text[word_end] == '\n' {
				if dest_idx < len(dest) {
					dest[dest_idx] = '\n'
					dest_idx += 1
				}
				current_line_width = 0
			}
			i = word_end + 1
		} else {
			i = word_end
		}
	}

	return string(dest[:dest_idx]), true
}
