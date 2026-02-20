package main

import "core:fmt"
import rl "vendor:raylib"

word_wrap :: proc(text: string, dest: []byte, max_width, font_size: i32) -> (string, bool) {
	if len(dest) == 0 {return "", false}

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
