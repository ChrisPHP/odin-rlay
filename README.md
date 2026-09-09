# odin-rlay
General UI layout creator in Odin with support for Raylib. It create cuts to rectangles to form the UI layout. 

![Screenshot example of UI made with odin-rlay](docs/odin-rlay-example.webp)

## Usage

You can find an example usage in `main.odin`. Full documentation will be added in the future.

## Memory

The `cut_multiple_*` / `cut_rect_evenly` procs return a slice. They allocate from
`context.temp_allocator` by default, so the returned slice is valid until the next
`free_all(context.temp_allocator)` — call that once per frame instead of deleting
each slice:

```odin
for !rl.WindowShouldClose() {
	defer free_all(context.temp_allocator)
	...
}
```

Pass an allocator explicitly for a longer lifetime (`rc.cut_multiple_top_percent(&rect, {0.5, 0.5}, allocator = context.allocator)`),
and `delete` the result yourself in that case. Every cut also has a non-allocating
`_into` variant that fills a caller supplied buffer. The buffer sets the piece count
for the `evenly` variants; for the percent variants it should hold one rect per
percent (extra percents are dropped), and `cut_rect_evenly_into` needs `len_col * len_col`:

```odin
rects: [3]rc.Rect
rc.cut_multiple_top_percent_into(&layout, {0.2, 0.6, 0.2}, rects[:])
```

## Gaps

Every `cut_multiple_*` and `cut_rect_evenly` proc takes an optional `gap`. Gaps sit
between pieces only, never before the first or after the last, so `n` pieces leave
`n - 1` gaps. The gaps are reserved before the rect is divided, so the pieces plus
the gaps always tile the original rect:

```odin
// three cards across the row, 20px between them
cards := rc.cut_multiple_evenly_width(&row, 3, gap = 20)

// same for percentages: the gaps come off first, then 30/70 splits the rest
panes := rc.cut_multiple_left_percent(&row, {0.3, 0.7}, gap = 20)
```

For `cut_rect_evenly` the gap applies to both axes. A negative gap is treated as
zero. Use `add_padding` for space around the outside of a rect; `gap` only handles
space between siblings.

## Leftovers

Percents that add up to 1 consume the rect exactly: the last piece takes the
remainder rather than its own rounded share, so its far edge lands on the parent's
and the rect is left empty. The `evenly` procs do the same. Without that the
divided size is rounded once per piece and the far edge can land a fraction of a
pixel short, which leaves a sliver that hit tests miss.

Percents that add up to less than 1 are left alone, so you can take a slice and
keep cutting what remains:

```odin
header := rc.cut_multiple_top_percent(&panel, {0.2, 0.3}) // 50% of panel left
footer := rc.cut_bottom_percent(&panel, 0.4)              // 40% of what remained
```
