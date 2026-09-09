package rlay

import "core:testing"

@(test)
gap_evenly :: proc(t: ^testing.T) {
	// 3 pieces, 2 gaps of 10 in a 100 wide rect -> 26.666 each
	r := Rect{0, 0, 100, 10}
	out: [3]Rect
	cut_multiple_evenly_width_into(&r, out[:], 10)
	piece := (f32(100) - 20) / 3
	// pieces tile the parent exactly, separated by the gap
	testing.expect_value(t, out[0].minx, f32(0))
	testing.expect_value(t, out[2].maxx, f32(100))
	for i in 0 ..< 2 {
		testing.expect_value(t, out[i].maxx + 10, out[i + 1].minx)
	}
	for o in out {
		testing.expect(t, abs((o.maxx - o.minx) - piece) < 1e-4, "piece not an even share")
	}
	// gap 0 matches old behaviour
	a, b := Rect{0, 0, 100, 10}, Rect{0, 0, 100, 10}
	oa, ob: [4]Rect
	cut_multiple_evenly_width_into(&a, oa[:], 0)
	cut_multiple_evenly_width_into(&b, ob[:])
	testing.expect_value(t, oa, ob)
}

@(test)
gap_percent :: proc(t: ^testing.T) {
	// gaps reserved first, percents split the remainder
	r := Rect{0, 0, 10, 100}
	out: [2]Rect
	cut_multiple_top_percent_into(&r, {0.5, 0.5}, out[:], 20)
	testing.expect_value(t, out[0], Rect{0, 0, 10, 40})
	testing.expect_value(t, out[1], Rect{0, 60, 10, 100})
}

@(test)
gap_edge_cases :: proc(t: ^testing.T) {
	// gap larger than the rect collapses pieces, never inverts
	r := Rect{0, 0, 100, 10}
	out: [3]Rect
	cut_multiple_evenly_width_into(&r, out[:], 500)
	for o in out {
		testing.expect(t, o.maxx >= o.minx, "piece inverted")
		testing.expect(t, o.minx >= 0 && o.maxx <= 100, "piece escaped parent")
	}
	// negative gap treated as zero
	x, y := Rect{0, 0, 100, 10}, Rect{0, 0, 100, 10}
	ox, oy: [3]Rect
	cut_multiple_evenly_width_into(&x, ox[:], -50)
	cut_multiple_evenly_width_into(&y, oy[:], 0)
	testing.expect_value(t, ox, oy)
	// grid gaps apply on both axes, cells stay inside the parent
	g := Rect{0, 0, 100, 100}
	cells: [9]Rect
	cut_rect_evenly_into(&g, 3, cells[:], 10)
	for c in cells {
		testing.expect(t, c.minx >= 0 && c.maxx <= 100, "cell escaped x")
		testing.expect(t, c.miny >= 0 && c.maxy <= 100, "cell escaped y")
	}
	testing.expect_value(t, cells[0], Rect{0, 0, 26.666666, 26.666666})
	testing.expect_value(t, cells[8].maxx, f32(100))
	testing.expect_value(t, cells[8].maxy, f32(100))
}

@(test)
padding_never_inverts :: proc(t: ^testing.T) {
	// .All meets in the middle rather than crossing over
	r := Rect{0, 0, 100, 40}
	add_padding(&r, 30)
	testing.expect_value(t, r, Rect{30, 20, 70, 20})
	// single sides clamp against the opposite edge
	r = Rect{0, 0, 100, 40}
	add_padding(&r, 500, .Top)
	testing.expect_value(t, r, Rect{0, 40, 100, 40})
	r = Rect{0, 0, 100, 40}
	add_padding(&r, 500, .Right)
	testing.expect_value(t, r, Rect{0, 0, 0, 40})
	// ordinary padding is unaffected, and negative padding still expands
	r = Rect{10, 10, 100, 40}
	add_padding(&r, 5)
	testing.expect_value(t, r, Rect{15, 15, 95, 35})
	r = Rect{10, 10, 100, 40}
	add_padding(&r, -5)
	testing.expect_value(t, r, Rect{5, 5, 105, 45})
}

@(test)
percent_remainder :: proc(t: ^testing.T) {
	// percents that cover the rect tile it exactly and leave nothing behind
	r := Rect{0, 0, 10, 100}
	out: [3]Rect
	cut_multiple_top_percent_into(&r, {0.1, 0.8, 0.1}, out[:])
	testing.expect_value(t, out[0].miny, f32(0))
	testing.expect_value(t, out[2].maxy, f32(100))
	testing.expect_value(t, get_total_rect_height(r), f32(0))
	for i in 0 ..< 2 {
		testing.expect_value(t, out[i].maxy, out[i + 1].miny)
	}

	// the same holds with a gap, and the gaps stay exact
	g := Rect{0, 0, 10, 100}
	gout: [3]Rect
	cut_multiple_top_percent_into(&g, {0.1, 0.8, 0.1}, gout[:], 7)
	testing.expect_value(t, gout[2].maxy, f32(100))
	testing.expect_value(t, get_total_rect_height(g), f32(0))
	for i in 0 ..< 2 {
		testing.expect_value(t, gout[i].maxy + 7, gout[i + 1].miny)
	}

	// a deliberate partial split still leaves its remainder in the rect
	p := Rect{0, 0, 10, 100}
	pout: [2]Rect
	cut_multiple_top_percent_into(&p, {0.2, 0.6}, pout[:])
	testing.expect_value(t, pout[1].maxy, f32(80))
	testing.expect_value(t, p, Rect{0, 80, 10, 100})

	// a short buffer drops trailing percents, so the rect is not consumed
	sr := Rect{0, 0, 10, 100}
	sout: [2]Rect
	cut_multiple_top_percent_into(&sr, {0.1, 0.8, 0.1}, sout[:])
	testing.expect_value(t, sout[1].maxy, f32(90))
	testing.expect_value(t, get_total_rect_height(sr), f32(10))

	// oversubscribed percents clamp instead of escaping the rect
	o := Rect{0, 0, 10, 100}
	oout: [3]Rect
	cut_multiple_top_percent_into(&o, {0.5, 0.5, 0.5}, oout[:])
	for c in oout {
		testing.expect(t, c.miny >= 0 && c.maxy <= 100, "piece escaped parent")
		testing.expect(t, c.maxy >= c.miny, "piece inverted")
	}

	// cutting from the other sides snaps the same way
	b := Rect{0, 0, 10, 100}
	bout: [3]Rect
	cut_multiple_bottom_percent_into(&b, {0.1, 0.8, 0.1}, bout[:])
	testing.expect_value(t, bout[2].miny, f32(0))
	testing.expect_value(t, get_total_rect_height(b), f32(0))

	l := Rect{0, 0, 100, 10}
	lout: [3]Rect
	cut_multiple_left_percent_into(&l, {0.1, 0.8, 0.1}, lout[:])
	testing.expect_value(t, lout[2].maxx, f32(100))
	testing.expect_value(t, get_total_rect_width(l), f32(0))
}

@(test)
percent_sweep_leaves_nothing :: proc(t: ^testing.T) {
	// Cutting each piece independently rounds the far edge short of the parent
	// in a small fraction of sizes. Sweep the splits and gaps the demo uses to
	// keep that from creeping back in.
	sets := [][]f32 {
		{0.1, 0.8, 0.1},
		{0.3, 0.4, 0.3},
		{0.1, 0.2, 0.5, 0.2},
		{0.2, 0.8},
		{0.3, 0.7},
		{1.0 / 3, 1.0 / 3, 1.0 / 3},
		{0.15, 0.35, 0.35, 0.15},
	}
	gaps := []f32{0, 7, 20, 30, 40}
	buf: [8]Rect
	leftovers, edge_mismatch := 0, 0
	for pcts in sets {
		for total := f32(50); total < 2600; total += 7 {
			for gap in gaps {
				r := Rect{0, 0, 10, total}
				out := buf[:len(pcts)]
				cut_multiple_top_percent_into(&r, pcts, out, gap)
				if get_total_rect_height(r) != 0 {leftovers += 1}
				if out[len(out) - 1].maxy != total {edge_mismatch += 1}
			}
		}
	}
	testing.expect_value(t, leftovers, 0)
	testing.expect_value(t, edge_mismatch, 0)
}
