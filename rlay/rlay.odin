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

// How far the percents may sum from 1 and still count as covering the whole
// rect. Summing a handful of f32 literals is off by ~1e-7, so this is far above
// the rounding error and far below any split a caller would write on purpose.
@(private)
PERCENT_FILL_EPSILON :: f32(1e-4)

// Fills `out` with one rect per percent. `gap` is reserved first (one gap
// between each pair of pieces, none before the first or after the last) and the
// percents are then measured against the space that remains. Writes
// min(len(percents), len(out)) rects, so a short buffer drops the trailing
// pieces rather than writing past its end.
//
// When the percents cover the whole rect the last piece takes the exact
// remainder instead of its own rounded share, so the pieces and gaps tile the
// rect and nothing is left behind. Percents that deliberately sum to less than
// one keep their leftover in the rect for the caller to carry on cutting.
@(private)
_cut_multiple_percent :: proc "contextless" (
	rect: ^Rect,
	percents: []f32,
	out: []Rect,
	gap: f32,
	dimension: proc "contextless" (_: Rect) -> f32,
	cut: proc "contextless" (_: ^Rect, _: f32) -> Rect,
) {
	count := min(len(percents), len(out))
	if count <= 0 {return}
	g := max(0, gap)
	usable := max(0, dimension(rect^) - g * f32(count - 1))

	sum: f32
	for p in percents[:count] {sum += p}
	fills_rect := abs(sum - 1) < PERCENT_FILL_EPSILON

	for p, i in percents[:count] {
		if i > 0 {cut(rect, g)}
		if fills_rect && i == count - 1 {
			out[i] = cut(rect, dimension(rect^))
		} else {
			out[i] = cut(rect, usable * p)
		}
	}
}

// The `*_into` variants write into a caller supplied buffer and never allocate.
cut_multiple_top_percent_into :: proc "contextless" (rect: ^Rect, percents: []f32, out: []Rect, gap: f32 = 0) {
	_cut_multiple_percent(rect, percents, out, gap, _rect_height, cut_top)
}
cut_multiple_bottom_percent_into :: proc "contextless" (rect: ^Rect, percents: []f32, out: []Rect, gap: f32 = 0) {
	_cut_multiple_percent(rect, percents, out, gap, _rect_height, cut_bottom)
}
cut_multiple_left_percent_into :: proc "contextless" (rect: ^Rect, percents: []f32, out: []Rect, gap: f32 = 0) {
	_cut_multiple_percent(rect, percents, out, gap, _rect_width, cut_left)
}
cut_multiple_right_percent_into :: proc "contextless" (rect: ^Rect, percents: []f32, out: []Rect, gap: f32 = 0) {
	_cut_multiple_percent(rect, percents, out, gap, _rect_width, cut_right)
}

cut_multiple_top_percent :: proc(rect: ^Rect, percents: []f32, gap: f32 = 0, allocator := context.temp_allocator) -> []Rect {
	result := make([]Rect, len(percents), allocator)
	cut_multiple_top_percent_into(rect, percents, result, gap)
	return result
}
cut_multiple_bottom_percent :: proc(rect: ^Rect, percents: []f32, gap: f32 = 0, allocator := context.temp_allocator) -> []Rect {
	result := make([]Rect, len(percents), allocator)
	cut_multiple_bottom_percent_into(rect, percents, result, gap)
	return result
}
cut_multiple_left_percent :: proc(rect: ^Rect, percents: []f32, gap: f32 = 0, allocator := context.temp_allocator) -> []Rect {
	result := make([]Rect, len(percents), allocator)
	cut_multiple_left_percent_into(rect, percents, result, gap)
	return result
}
cut_multiple_right_percent :: proc(rect: ^Rect, percents: []f32, gap: f32 = 0, allocator := context.temp_allocator) -> []Rect {
	result := make([]Rect, len(percents), allocator)
	cut_multiple_right_percent_into(rect, percents, result, gap)
	return result
}

// Splits the rect into a `len_col` x `len_col` grid, row major, consuming the
// grid's height from the top of the rect. `gap` separates neighbouring cells in
// both axes and is not applied outside the grid. `out` must hold
// len_col * len_col rects; a shorter buffer leaves both `out` and the rect
// untouched.
cut_rect_evenly_into :: proc "contextless" (rect: ^Rect, len_col: int, out: []Rect, gap: f32 = 0) {
	if len_col <= 0 || len(out) < len_col * len_col {return}
	g := max(0, gap)
	height := max(0, get_total_rect_height(rect) - g * f32(len_col - 1)) / f32(len_col)
	for row in 0 ..< len_col {
		if row > 0 {cut_top(rect, g)}
		r := cut_top(rect, height if row < len_col - 1 else get_total_rect_height(rect))
		cut_multiple_evenly_width_into(&r, out[row * len_col:][:len_col], g)
	}
}

cut_rect_evenly :: proc(rect: ^Rect, len_col: int, gap: f32 = 0, allocator := context.temp_allocator) -> []Rect {
	if len_col <= 0 {return nil}
	result := make([]Rect, len_col * len_col, allocator)
	cut_rect_evenly_into(rect, len_col, result, gap)
	return result
}

// Splits the rect into `len(out)` equal pieces, separated by `gap`. The gaps sit
// between pieces only, so `len(out) - 1` of them are removed from the total
// before it is divided. A negative `gap` is treated as zero.
//
// The last piece takes whatever is left rather than a recomputed share, so the
// pieces and gaps tile the rect exactly. Without that the divided size is
// rounded `len(out)` times and the far edge drifts by a few ulp, which leaves
// a sliver that hit tests miss.
cut_multiple_evenly_height_into :: proc "contextless" (rect: ^Rect, out: []Rect, gap: f32 = 0) {
	if len(out) == 0 {return}
	g := max(0, gap)
	height_piece := max(0, get_total_rect_height(rect) - g * f32(len(out) - 1)) / f32(len(out))
	for i in 0 ..< len(out) {
		if i > 0 {cut_top(rect, g)}
		if i == len(out) - 1 {
			out[i] = cut_top(rect, get_total_rect_height(rect))
		} else {
			out[i] = cut_top(rect, height_piece)
		}
	}
}

cut_multiple_evenly_width_into :: proc "contextless" (rect: ^Rect, out: []Rect, gap: f32 = 0) {
	if len(out) == 0 {return}
	g := max(0, gap)
	width_piece := max(0, get_total_rect_width(rect) - g * f32(len(out) - 1)) / f32(len(out))
	for i in 0 ..< len(out) {
		if i > 0 {cut_left(rect, g)}
		if i == len(out) - 1 {
			out[i] = cut_left(rect, get_total_rect_width(rect))
		} else {
			out[i] = cut_left(rect, width_piece)
		}
	}
}

cut_multiple_evenly_height :: proc(rect: ^Rect, pieces: int, gap: f32 = 0, allocator := context.temp_allocator) -> []Rect {
	if pieces <= 0 {return nil}
	result := make([]Rect, pieces, allocator)
	cut_multiple_evenly_height_into(rect, result, gap)
	return result
}

cut_multiple_evenly_width :: proc(rect: ^Rect, pieces: int, gap: f32 = 0, allocator := context.temp_allocator) -> []Rect {
	if pieces <= 0 {return nil}
	result := make([]Rect, pieces, allocator)
	cut_multiple_evenly_width_into(rect, result, gap)
	return result
}

// Insets the rect by `padding` on the given side(s). Like the `cut_*` procs
// the edges are clamped so a rect can shrink to zero size but never invert.
// For `.All`, opposite edges meet at the centre when padding exceeds half the size.
add_padding :: proc "contextless" (rect: ^Rect, padding: f32, padding_type: Padding = .All) {
	switch padding_type {
	case .All:
		half_w := get_total_rect_width(rect) / 2
		half_h := get_total_rect_height(rect) / 2
		px := min(padding, half_w)
		py := min(padding, half_h)
		rect.minx += px
		rect.maxx -= px
		rect.miny += py
		rect.maxy -= py
	case .Top:
		rect.miny = min(rect.maxy, rect.miny + padding)
	case .Bottom:
		rect.maxy = max(rect.miny, rect.maxy - padding)
	case .Left:
		rect.minx = min(rect.maxx, rect.minx + padding)
	case .Right:
		rect.maxx = max(rect.minx, rect.maxx - padding)
	}
}

rect_to_raylib :: proc "contextless" (rect: Rect) -> rl.Rectangle {
	return rl.Rectangle {
		x      = rect.minx,
		y      = rect.miny,
		width  = get_total_rect_width(rect),
		height = get_total_rect_height(rect),
	}
}

// Size of a rect clamped to zero for inverted rects. Accept both a value and a
// pointer so procs holding a `Rect` by value can reuse them.
get_total_rect_width :: proc {
	_rect_width,
	_rect_width_ptr,
}
get_total_rect_height :: proc {
	_rect_height,
	_rect_height_ptr,
}

@(private)
_rect_width :: proc "contextless" (rect: Rect) -> f32 {
	return max(0, rect.maxx - rect.minx)
}
@(private)
_rect_height :: proc "contextless" (rect: Rect) -> f32 {
	return max(0, rect.maxy - rect.miny)
}
@(private)
_rect_width_ptr :: proc "contextless" (rect: ^Rect) -> f32 {
	return _rect_width(rect^)
}
@(private)
_rect_height_ptr :: proc "contextless" (rect: ^Rect) -> f32 {
	return _rect_height(rect^)
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

// Draws a themed button, `.Accent` when `current == selected` and `.Secondary`
// otherwise, and reports whether it was clicked this frame.
draw_rect_button :: proc "contextless" (rect: Rect, current, selected: $T) -> bool {
	draw_rect_ui(rect, .Accent if current == selected else .Secondary)
	return rect_button(rect)
}

rect_button :: proc "contextless" (rect: Rect) -> bool {
	if !rl.IsMouseButtonPressed(.LEFT) {return false}
	return rl.CheckCollisionPointRec(rl.GetMousePosition(), rect_to_raylib(rect))
}


// `progress` is clamped to 0..1 so out-of-range or NaN input can never grow
// the rect or draw outside it.
draw_progress_bar :: proc "contextless" (rect: ^Rect, progress: f32) {
	progress := progress
	if progress != progress {progress = 0} // NaN
	progress = clamp(progress, 0, 1)
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
	// Measuring walks every glyph and only the centred and right aligned
	// cases need the width, so keep it out of the left aligned path.
	text_width: f32
	if align != .Left {
		text_width = rl.MeasureTextEx(FONT, text, font_size, TEXT_SPACING).x
	}

	// `padding` insets the text from the aligned edge for both .Left and .Right.
	x: f32
	y := rect.miny + (get_total_rect_height(rect) - font_size) / 2
	switch align {
	case .Left:
		x = rect.minx + padding
	case .Center:
		x = rect.minx + (get_total_rect_width(rect) - text_width) / 2
	case .Right:
		x = rect.maxx - text_width - padding
	}

	rl.DrawTextEx(FONT, text, {x, y}, font_size, TEXT_SPACING, colour)
}
