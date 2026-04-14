package rlay

import rl "vendor:raylib"

Rect :: struct {
	minx, miny, maxx, maxy: f32,
}

UIColor :: enum {
	Background,
	Primary,
	Secondary,
	Accent,
	Raised,
	Sunken,
}

TextAlign :: enum {
	Left,
	Center,
	Right,
}

Padding :: enum {
	Top,
	Bottom,
	Left,
	Right,
	All,
}

TextColor :: enum {
	Main,
	Muted,
	Dim,
}

ColorUI :: struct {
	Text:       rl.Color,
	Background: rl.Color,
	Primary:    rl.Color,
	Secondary:  rl.Color,
	Accent:     rl.Color,

	// derived
	Bg_Raised:  rl.Color,
	Bg_Sunken:  rl.Color,
	Text_Muted: rl.Color,
	Text_Dim:   rl.Color,
}

COLOUR_UI := ColorUI {
	Text       = rl.Color{5, 3, 21, 255},
	Background = rl.Color{251, 251, 254, 255},
	Primary    = rl.Color{47, 39, 206, 255},
	Secondary  = rl.Color{222, 220, 255, 255},
	Accent     = rl.Color{67, 59, 255, 255},
	Bg_Raised  = rl.Color{255, 255, 255, 255},
	Bg_Sunken  = rl.Color{239, 239, 242, 255},
	Text_Muted = rl.Color{5, 3, 21, 140},
	Text_Dim   = rl.Color{5, 3, 21, 76},
}

FONT: rl.Font


get_text_color :: proc(color: TextColor) -> rl.Color {
	switch color {
	case .Main:
		return COLOUR_UI.Text
	case .Muted:
		return COLOUR_UI.Text_Muted
	case .Dim:
		return COLOUR_UI.Text_Dim
	}
	return COLOUR_UI.Text
}

get_ui_color :: proc(role: UIColor) -> rl.Color {
	switch role {
	case .Background:
		return COLOUR_UI.Background
	case .Primary:
		return COLOUR_UI.Primary
	case .Secondary:
		return COLOUR_UI.Secondary
	case .Accent:
		return COLOUR_UI.Accent
	case .Raised:
		return COLOUR_UI.Bg_Raised
	case .Sunken:
		return COLOUR_UI.Bg_Sunken
	}
	return COLOUR_UI.Background
}

with_alpha :: proc(c: rl.Color, alpha: u8) -> rl.Color {
	return rl.Color{c.r, c.g, c.b, alpha}
}

colour_shift :: proc(c: rl.Color, amount: i16) -> rl.Color {
	clamp_u8 :: proc(v: i16) -> u8 {return u8(clamp(v, 0, 255))}
	return rl.Color {
		clamp_u8(i16(c.r) + amount),
		clamp_u8(i16(c.g) + amount),
		clamp_u8(i16(c.b) + amount),
		c.a,
	}
}

init_ui_colours :: proc(text, background, primary, secondary, accent: rl.Color) {
	COLOUR_UI.Text = text
	COLOUR_UI.Background = background
	COLOUR_UI.Primary = primary
	COLOUR_UI.Secondary = secondary
	COLOUR_UI.Accent = accent
	COLOUR_UI.Bg_Raised = colour_shift(background, +12)
	COLOUR_UI.Bg_Sunken = colour_shift(background, -12)
	COLOUR_UI.Text_Muted = with_alpha(text, 140) // ~55%
	COLOUR_UI.Text_Dim = with_alpha(text, 76) // ~30%
}

init_font :: proc(font: rl.Font) {
	FONT = font
}

cut_left :: proc(rect: ^Rect, a: f32) -> Rect {
	minx := rect.minx
	rect.minx = min(rect.maxx, rect.minx + a)
	return Rect{minx, rect.miny, rect.minx, rect.maxy}
}

cut_right :: proc(rect: ^Rect, a: f32) -> Rect {
	maxx := rect.maxx
	rect.maxx = max(rect.minx, rect.maxx - a)
	return Rect{rect.maxx, rect.miny, maxx, rect.maxy}
}

cut_top :: proc(rect: ^Rect, a: f32) -> Rect {
	miny := rect.miny
	rect.miny = min(rect.maxy, rect.miny + a)
	return Rect{rect.minx, miny, rect.maxx, rect.miny}
}

cut_bottom :: proc(rect: ^Rect, a: f32) -> Rect {
	maxy := rect.maxy
	rect.maxy = max(rect.miny, rect.maxy - a)
	return Rect{rect.minx, rect.maxy, rect.maxx, maxy}
}

cut_left_percent :: proc(rect: ^Rect, percent: f32) -> Rect {
	a := (rect.maxx - rect.minx) * percent
	minx := rect.minx
	rect.minx = min(rect.maxx, rect.minx + a)
	return Rect{minx, rect.miny, rect.minx, rect.maxy}
}

cut_right_percent :: proc(rect: ^Rect, percent: f32) -> Rect {
	a := (rect.maxx - rect.minx) * percent
	maxx := rect.maxx
	rect.maxx = max(rect.minx, rect.maxx - a)
	return Rect{rect.maxx, rect.miny, maxx, rect.maxy}
}

cut_top_percent :: proc(rect: ^Rect, percent: f32) -> Rect {
	a := (rect.maxy - rect.miny) * percent
	miny := rect.miny
	rect.miny = min(rect.maxy, rect.miny + a)
	return Rect{rect.minx, miny, rect.maxx, rect.miny}
}

cut_bottom_percent :: proc(rect: ^Rect, percent: f32) -> Rect {
	a := (rect.maxy - rect.miny) * percent
	maxy := rect.maxy
	rect.maxy = max(rect.miny, rect.maxy - a)
	return Rect{rect.minx, rect.maxy, rect.maxx, maxy}
}

_cut_multiple_percent :: proc(
	rect: ^Rect,
	percents: []f32,
	get_dimension: proc(_: ^Rect) -> f32,
	cut: proc(_: ^Rect, _: f32) -> Rect,
) -> []Rect {
	length := len(percents)
	result := make([]Rect, length)
	total := get_dimension(rect)
	for p, i in percents {
		result[i] = cut(rect, total * p)
	}
	return result
}

cut_multiple_top_percent :: proc(rect: ^Rect, percents: []f32) -> []Rect {
	return _cut_multiple_percent(rect, percents, get_total_rect_height, cut_top)
}
cut_multiple_bottom_percent :: proc(rect: ^Rect, percents: []f32) -> []Rect {
	return _cut_multiple_percent(rect, percents, get_total_rect_height, cut_bottom)
}
cut_multiple_left_percent :: proc(rect: ^Rect, percents: []f32) -> []Rect {
	return _cut_multiple_percent(rect, percents, get_total_rect_width, cut_left)
}
cut_multiple_right_percent :: proc(rect: ^Rect, percents: []f32) -> []Rect {
	return _cut_multiple_percent(rect, percents, get_total_rect_width, cut_right)
}

cut_rect_evenly :: proc(rect: ^Rect, len_col: f32) -> []Rect {
	result := make([]Rect, int(len_col * len_col))
	rows := cut_multiple_evenly_height(rect, len_col)
	defer delete(rows)

	index := 0
	for &r in rows {
		cols := cut_multiple_evenly_width(&r, len_col)
		defer delete(cols)
		for c in cols {
			result[index] = c
			index += 1
		}
	}
	return result
}

cut_multiple_evenly_height :: proc(rect: ^Rect, pieces: f32) -> []Rect {
	result := make([]Rect, int(pieces))
	perc := 1.0 / pieces
	total_height := get_total_rect_height(rect)
	height_piece := total_height / pieces
	for _, i in 0 ..< pieces {
		result[i] = cut_top(rect, height_piece)
	}
	return result
}

cut_multiple_evenly_width :: proc(rect: ^Rect, pieces: f32) -> []Rect {
	result := make([]Rect, int(pieces))
	perc := 1.0 / pieces
	total_width := get_total_rect_width(rect)
	width_piece := total_width / pieces

	for _, i in 0 ..< pieces {
		result[i] = cut_left(rect, width_piece)
	}
	return result
}

add_padding :: proc(rect: ^Rect, padding: f32, padding_type: Padding = .All) {
	switch padding_type {
	case .All:
		rect.minx += padding
		rect.miny += padding
		rect.maxx -= padding
		rect.maxy -= padding
	case .Top:
		rect.miny += padding
	case .Bottom:
		rect.maxy -= padding
	case .Left:
		rect.minx += padding
	case .Right:
		rect.maxx -= padding
	}
}

rect_to_raylib :: proc(rect: Rect) -> rl.Rectangle {
	width := max(0, rect.maxx - rect.minx)
	height := max(0, rect.maxy - rect.miny)
	return rl.Rectangle{x = rect.minx, y = rect.miny, width = width, height = height}
}

get_total_rect_width :: proc(rect: ^Rect) -> f32 {
	return max(0, rect.maxx - rect.minx)
}

get_total_rect_height :: proc(rect: ^Rect) -> f32 {
	return max(0, rect.maxy - rect.miny)
}

// Converts a pixel corner radius to raylib's roundness ratio.
// raylib computes corner_radius = roundness * min(width, height) / 2,
// so we invert that to keep corners a fixed pixel size regardless of rect dimensions.
radius_to_roundness :: proc(rl_rect: rl.Rectangle, radius: f32) -> f32 {
	min_dim := min(rl_rect.width, rl_rect.height)
	if min_dim <= 0 {return 0}
	return clamp(2.0 * radius / min_dim, 0.0, 1.0)
}


draw_rect_ui :: proc(
	rect: Rect,
	role: UIColor,
	border_color: rl.Color = {0, 0, 0, 0},
	radius: f32 = 0.0,
	segments: i32 = 8,
	border_size: f32 = 2,
) {
	draw_rect(rect, get_ui_color(role), border_color, radius, segments, border_size)
}

draw_rect :: proc(
	rect: Rect,
	color: rl.Color,
	border_color: rl.Color = {0, 0, 0, 0},
	radius: f32 = 0.0,
	segments: i32 = 8,
	border_size: f32 = 2,
) {
	rl_rect := rect_to_raylib(rect)
	if radius > 0 {
		roundness := radius_to_roundness(rl_rect, radius)
		rl.DrawRectangleRounded(rl_rect, roundness, segments, color)
		if border_color.a > 0 do rl.DrawRectangleRoundedLinesEx(rl_rect, roundness, segments, border_size, border_color)
	} else {
		rl.DrawRectangleRec(rl_rect, color)
		if border_color.a > 0 do rl.DrawRectangleLinesEx(rl_rect, border_size, border_color)
	}
}

draw_rect_button :: proc(rect: Rect, current, selected: $T) -> bool {
	rl_rect := rect_to_raylib(rect)
	if current == selected {
		rl.DrawRectangleRec(rl_rect, rl.Color{22, 163, 74, 255})
	} else {
		rl.DrawRectangleRec(rl_rect, rl.Color{75, 85, 99, 255})
	}

	mouse_pos := rl.GetMousePosition()
	if rl.CheckCollisionPointRec(mouse_pos, rl_rect) {
		if rl.IsMouseButtonPressed(.LEFT) {
			return true
		}
	}
	return false
}

rect_button :: proc(rect: Rect) -> bool {
	mouse_pos := rl.GetMousePosition()
	if rl.CheckCollisionPointRec(mouse_pos, rect_to_raylib(rect)) {
		if rl.IsMouseButtonPressed(.LEFT) {
			return true
		}
	}
	return false
}


draw_progress_bar :: proc(rect: ^Rect, progress: f32) {
	bar_width := get_total_rect_width(rect)
	bar_progress := cut_left(rect, bar_width * progress)
	draw_rect(bar_progress, rl.GREEN, rl.WHITE)
	draw_rect(rect^, rl.GRAY, rl.WHITE)
}

draw_text_ui :: proc(
	text: cstring,
	rect: Rect,
	role: TextColor,
	font_size: f32,
	align: TextAlign,
	padding: f32 = 0,
) {
	text_width := rl.MeasureTextEx(FONT, text, font_size, 5)
	rect_width := rect.maxx - rect.minx
	rect_height := rect.maxy - rect.miny

	x := rect.minx + padding
	y := rect.miny + (rect_height - f32(font_size)) / 2

	color := get_text_color(role)
	switch align {
	case .Left:
		x = rect.minx + padding
		y = rect.miny + (rect_height - f32(font_size)) / 2
	case .Center:
		x = rect.minx + ((rect_width / 2) - f32(text_width.x / 2))
		y = rect.miny + (rect_height - f32(font_size)) / 2
	case .Right:
		x = rect.maxx - (text_width.x - padding)
		y = rect.miny + (rect_height - f32(font_size)) / 2
	}

	//rl.DrawText(text, i32(x), i32(y), font_size, color)
	rl.DrawTextEx(FONT, text, [2]f32{x, y}, f32(font_size), 5, color)
}

draw_text :: proc(
	text: cstring,
	rect: Rect,
	colour: rl.Color,
	font_size: f32,
	align: TextAlign,
	padding: f32 = 0,
) {
	text_width := rl.MeasureTextEx(FONT, text, font_size, 5)
	rect_width := rect.maxx - rect.minx
	rect_height := rect.maxy - rect.miny

	x := rect.minx + padding
	y := rect.miny + (rect_height - f32(font_size)) / 2

	switch align {
	case .Left:
		x = rect.minx + padding
		y = rect.miny + (rect_height - f32(font_size)) / 2
	case .Center:
		x = rect.minx + ((rect_width / 2) - f32(text_width.x / 2))
		y = rect.miny + (rect_height - f32(font_size)) / 2
	case .Right:
		x = rect.maxx - f32(text_width.x) - padding
		y = rect.miny + (rect_height - f32(font_size)) / 2
	}

	rl.DrawTextEx(FONT, text, [2]f32{x, y}, f32(font_size), 5, colour)
}
