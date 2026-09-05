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

// Glyph spacing passed to raylib for every measure/draw call.
TEXT_SPACING :: f32(5)


get_text_color :: proc "contextless" (color: TextColor) -> rl.Color {
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

get_ui_color :: proc "contextless" (role: UIColor) -> rl.Color {
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

with_alpha :: proc "contextless" (c: rl.Color, alpha: u8) -> rl.Color {
	return rl.Color{c.r, c.g, c.b, alpha}
}

colour_shift :: proc "contextless" (c: rl.Color, amount: i16) -> rl.Color {
	clamp_u8 :: proc "contextless" (v: i16) -> u8 {return u8(clamp(v, 0, 255))}
	return rl.Color {
		clamp_u8(i16(c.r) + amount),
		clamp_u8(i16(c.g) + amount),
		clamp_u8(i16(c.b) + amount),
		c.a,
	}
}

init_ui_colours :: proc "contextless" (text, background, primary, secondary, accent: rl.Color) {
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

init_font :: proc "contextless" (font: rl.Font) {
	FONT = font
}

cut_left :: proc "contextless" (rect: ^Rect, a: f32) -> Rect {
	minx := rect.minx
	rect.minx = min(rect.maxx, rect.minx + a)
	return Rect{minx, rect.miny, rect.minx, rect.maxy}
}

cut_right :: proc "contextless" (rect: ^Rect, a: f32) -> Rect {
	maxx := rect.maxx
	rect.maxx = max(rect.minx, rect.maxx - a)
	return Rect{rect.maxx, rect.miny, maxx, rect.maxy}
}

cut_top :: proc "contextless" (rect: ^Rect, a: f32) -> Rect {
	miny := rect.miny
	rect.miny = min(rect.maxy, rect.miny + a)
	return Rect{rect.minx, miny, rect.maxx, rect.miny}
}

cut_bottom :: proc "contextless" (rect: ^Rect, a: f32) -> Rect {
	maxy := rect.maxy
	rect.maxy = max(rect.miny, rect.maxy - a)
	return Rect{rect.minx, rect.maxy, rect.maxx, maxy}
}

cut_left_percent :: proc "contextless" (rect: ^Rect, percent: f32) -> Rect {
	return cut_left(rect, get_total_rect_width(rect) * percent)
}

cut_right_percent :: proc "contextless" (rect: ^Rect, percent: f32) -> Rect {
	return cut_right(rect, get_total_rect_width(rect) * percent)
}

cut_top_percent :: proc "contextless" (rect: ^Rect, percent: f32) -> Rect {
	return cut_top(rect, get_total_rect_height(rect) * percent)
}

cut_bottom_percent :: proc "contextless" (rect: ^Rect, percent: f32) -> Rect {
	return cut_bottom(rect, get_total_rect_height(rect) * percent)
}

@(private)
Side :: enum {
	Top,
	Bottom,
	Left,
	Right,
}

// Fills `out` with one rect per percent, each measured against the size the
// rect had before any cut was made.
@(private)
_cut_multiple_percent :: proc "contextless" (rect: ^Rect, percents: []f32, out: []Rect, side: Side) {
	switch side {
	case .Top:
		total := get_total_rect_height(rect)
		for p, i in percents {out[i] = cut_top(rect, total * p)}
	case .Bottom:
		total := get_total_rect_height(rect)
		for p, i in percents {out[i] = cut_bottom(rect, total * p)}
	case .Left:
		total := get_total_rect_width(rect)
		for p, i in percents {out[i] = cut_left(rect, total * p)}
	case .Right:
		total := get_total_rect_width(rect)
		for p, i in percents {out[i] = cut_right(rect, total * p)}
	}
}

// The `*_into` variants write into a caller supplied buffer and never allocate.
cut_multiple_top_percent_into :: proc "contextless" (rect: ^Rect, percents: []f32, out: []Rect) {
	_cut_multiple_percent(rect, percents, out, .Top)
}
cut_multiple_bottom_percent_into :: proc "contextless" (rect: ^Rect, percents: []f32, out: []Rect) {
	_cut_multiple_percent(rect, percents, out, .Bottom)
}
cut_multiple_left_percent_into :: proc "contextless" (rect: ^Rect, percents: []f32, out: []Rect) {
	_cut_multiple_percent(rect, percents, out, .Left)
}
cut_multiple_right_percent_into :: proc "contextless" (rect: ^Rect, percents: []f32, out: []Rect) {
	_cut_multiple_percent(rect, percents, out, .Right)
}

@(private)
_cut_multiple_percent_alloc :: proc(
	rect: ^Rect,
	percents: []f32,
	side: Side,
	allocator := context.temp_allocator,
) -> []Rect {
	result := make([]Rect, len(percents), allocator)
	_cut_multiple_percent(rect, percents, result, side)
	return result
}

cut_multiple_top_percent :: proc(rect: ^Rect, percents: []f32, allocator := context.temp_allocator) -> []Rect {
	return _cut_multiple_percent_alloc(rect, percents, .Top, allocator)
}
cut_multiple_bottom_percent :: proc(rect: ^Rect, percents: []f32, allocator := context.temp_allocator) -> []Rect {
	return _cut_multiple_percent_alloc(rect, percents, .Bottom, allocator)
}
cut_multiple_left_percent :: proc(rect: ^Rect, percents: []f32, allocator := context.temp_allocator) -> []Rect {
	return _cut_multiple_percent_alloc(rect, percents, .Left, allocator)
}
cut_multiple_right_percent :: proc(rect: ^Rect, percents: []f32, allocator := context.temp_allocator) -> []Rect {
	return _cut_multiple_percent_alloc(rect, percents, .Right, allocator)
}

// Splits the rect into a `len_col` x `len_col` grid, row major.
cut_rect_evenly_into :: proc "contextless" (rect: ^Rect, len_col: int, out: []Rect) {
	if len_col <= 0 {return}
	x, y := rect.minx, rect.miny
	width := get_total_rect_width(rect) / f32(len_col)
	height := get_total_rect_height(rect) / f32(len_col)

	for row in 0 ..< len_col {
		miny := y + f32(row) * height
		for col in 0 ..< len_col {
			minx := x + f32(col) * width
			out[row * len_col + col] = Rect{minx, miny, minx + width, miny + height}
		}
	}
	rect.miny = min(rect.maxy, y + height * f32(len_col))
}

cut_rect_evenly :: proc(rect: ^Rect, len_col: int, allocator := context.temp_allocator) -> []Rect {
	if len_col <= 0 {return nil}
	result := make([]Rect, len_col * len_col, allocator)
	cut_rect_evenly_into(rect, len_col, result)
	return result
}

cut_multiple_evenly_height_into :: proc "contextless" (rect: ^Rect, out: []Rect) {
	height_piece := get_total_rect_height(rect) / f32(len(out))
	for i in 0 ..< len(out) {
		out[i] = cut_top(rect, height_piece)
	}
}

cut_multiple_evenly_width_into :: proc "contextless" (rect: ^Rect, out: []Rect) {
	width_piece := get_total_rect_width(rect) / f32(len(out))
	for i in 0 ..< len(out) {
		out[i] = cut_left(rect, width_piece)
	}
}

cut_multiple_evenly_height :: proc(rect: ^Rect, pieces: int, allocator := context.temp_allocator) -> []Rect {
	if pieces <= 0 {return nil}
	result := make([]Rect, pieces, allocator)
	cut_multiple_evenly_height_into(rect, result)
	return result
}

cut_multiple_evenly_width :: proc(rect: ^Rect, pieces: int, allocator := context.temp_allocator) -> []Rect {
	if pieces <= 0 {return nil}
	result := make([]Rect, pieces, allocator)
	cut_multiple_evenly_width_into(rect, result)
	return result
}

add_padding :: proc "contextless" (rect: ^Rect, padding: f32, padding_type: Padding = .All) {
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

rect_to_raylib :: proc "contextless" (rect: Rect) -> rl.Rectangle {
	return rl.Rectangle {
		x      = rect.minx,
		y      = rect.miny,
		width  = max(0, rect.maxx - rect.minx),
		height = max(0, rect.maxy - rect.miny),
	}
}

get_total_rect_width :: proc "contextless" (rect: ^Rect) -> f32 {
	return max(0, rect.maxx - rect.minx)
}

get_total_rect_height :: proc "contextless" (rect: ^Rect) -> f32 {
	return max(0, rect.maxy - rect.miny)
}

// Converts a pixel corner radius to raylib's roundness ratio.
// raylib computes corner_radius = roundness * min(width, height) / 2,
// so we invert that to keep corners a fixed pixel size regardless of rect dimensions.
radius_to_roundness :: proc "contextless" (rl_rect: rl.Rectangle, radius: f32) -> f32 {
	min_dim := min(rl_rect.width, rl_rect.height)
	if min_dim <= 0 {return 0}
	return clamp(2.0 * radius / min_dim, 0.0, 1.0)
}


draw_rect_ui :: proc "contextless" (
	rect: Rect,
	role: UIColor,
	border_color: rl.Color = {0, 0, 0, 0},
	radius: f32 = 0.0,
	segments: i32 = 8,
	border_size: f32 = 2,
) {
	draw_rect(rect, get_ui_color(role), border_color, radius, segments, border_size)
}

draw_rect :: proc "contextless" (
	rect: Rect,
	color: rl.Color,
	border_color: rl.Color = {0, 0, 0, 0},
	radius: f32 = 0.0,
	segments: i32 = 8,
	border_size: f32 = 2,
) {
	rl_rect := rect_to_raylib(rect)
	if rl_rect.width <= 0 || rl_rect.height <= 0 {return}
	if radius > 0 {
		roundness := radius_to_roundness(rl_rect, radius)
		rl.DrawRectangleRounded(rl_rect, roundness, segments, color)
		if border_color.a > 0 do rl.DrawRectangleRoundedLinesEx(rl_rect, roundness, segments, border_size, border_color)
	} else {
		rl.DrawRectangleRec(rl_rect, color)
		if border_color.a > 0 do rl.DrawRectangleLinesEx(rl_rect, border_size, border_color)
	}
}

draw_rect_button :: proc "contextless" (rect: Rect, current, selected: $T) -> bool {
	rl_rect := rect_to_raylib(rect)
	if current == selected {
		rl.DrawRectangleRec(rl_rect, rl.Color{22, 163, 74, 255})
	} else {
		rl.DrawRectangleRec(rl_rect, rl.Color{75, 85, 99, 255})
	}
	return _hit_rect(rl_rect)
}

rect_button :: proc "contextless" (rect: Rect) -> bool {
	return _hit_rect(rect_to_raylib(rect))
}

@(private)
_hit_rect :: proc "contextless" (rl_rect: rl.Rectangle) -> bool {
	if !rl.IsMouseButtonPressed(.LEFT) {return false}
	return rl.CheckCollisionPointRec(rl.GetMousePosition(), rl_rect)
}


draw_progress_bar :: proc "contextless" (rect: ^Rect, progress: f32) {
	bar_width := get_total_rect_width(rect)
	bar_progress := cut_left(rect, bar_width * progress)
	draw_rect(bar_progress, rl.GREEN, rl.WHITE)
	draw_rect(rect^, rl.GRAY, rl.WHITE)
}

draw_text_ui :: proc "contextless" (
	text: cstring,
	rect: Rect,
	role: TextColor,
	font_size: f32,
	align: TextAlign,
	padding: f32 = 0,
) {
	draw_text(text, rect, get_text_color(role), font_size, align, padding)
}

draw_text :: proc "contextless" (
	text: cstring,
	rect: Rect,
	colour: rl.Color,
	font_size: f32,
	align: TextAlign,
	padding: f32 = 0,
) {
	x := rect.minx + padding
	y := rect.miny + ((rect.maxy - rect.miny) - font_size) / 2

	// Only the centred and right aligned cases need the width of the text,
	// and measuring walks every glyph, so keep it out of the left aligned path.
	switch align {
	case .Left:
	case .Center:
		text_width := rl.MeasureTextEx(FONT, text, font_size, TEXT_SPACING).x
		x = rect.minx + ((rect.maxx - rect.minx) - text_width) / 2
	case .Right:
		text_width := rl.MeasureTextEx(FONT, text, font_size, TEXT_SPACING).x
		x = rect.maxx - text_width - padding
	}

	rl.DrawTextEx(FONT, text, {x, y}, font_size, TEXT_SPACING, colour)
}
