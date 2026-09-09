package main

import rc "rlay"
import rl "vendor:raylib"

GameState :: enum {
	Main_Menu,
	Playing,
	Settings,
	Pause,
}

ScreenSize :: struct {
	width:  f32,
	height: f32,
}

UiContent :: struct {
	top_banner:    rc.Rect,
	left_sidebar:  rc.Rect,
	center:        rc.Rect,
	right_sidebar: rc.Rect,
	bottom_banner: rc.Rect,
}

UI_CONTENT: UiContent
SCREEN_SIZE: ScreenSize

ui_initial_setup :: proc() {
	layout := rc.Rect{0, 0, SCREEN_SIZE.width, SCREEN_SIZE.height}
	top_bottom_bars, sidebars_and_center: [3]rc.Rect
	rc.cut_multiple_top_percent_into(&layout, {0.1, 0.8, 0.1}, top_bottom_bars[:])
	rc.cut_multiple_left_percent_into(&top_bottom_bars[1], {0.1, 0.8, 0.1}, sidebars_and_center[:])

	UI_CONTENT = UiContent {
		top_banner    = top_bottom_bars[0],
		left_sidebar  = sidebars_and_center[0],
		center        = sidebars_and_center[1],
		right_sidebar = sidebars_and_center[2],
		bottom_banner = top_bottom_bars[2],
	}
}

main :: proc() {
	rl.InitWindow(0, 0, "Odin Rlay")
	rl.SetTargetFPS(60)
	rl.ToggleBorderlessWindowed()

	SCREEN_SIZE.width = f32(rl.GetRenderWidth())
	SCREEN_SIZE.height = f32(rl.GetRenderHeight())

	ui_initial_setup()
	rc.init_font(rl.GetFontDefault())
	rc.init_ui_colours(
		text = rl.Color{240, 231, 227, 255},
		background = rl.Color{66, 57, 52, 255},
		primary = rl.Color{220, 172, 146, 255},
		secondary = rl.Color{130, 65, 31, 255},
		accent = rl.Color{220, 103, 40, 255},
	)

	for !rl.WindowShouldClose() {
		// Every layout slice below lives in the temp allocator, so one reset per
		// frame replaces a malloc/free pair per cut.
		defer free_all(context.temp_allocator)

		rl.BeginDrawing()
		rl.ClearBackground(rl.WHITE)

		rc.draw_rect_ui(UI_CONTENT.center, .Background, radius = 30)
		center := UI_CONTENT.center
		rc.add_padding(&center, 20)
		split_wdith := rc.cut_multiple_left_percent(&center, {0.3, 0.7})
		sidebar := split_wdith[0]
		rc.add_padding(&sidebar, 40)
		rc.draw_rect_ui(sidebar, .Sunken, radius = 30)

		sidebar_header := rc.cut_top_percent(&sidebar, 0.1)
		rc.draw_text_ui("Sidebar Header", sidebar_header, .Muted, 50, .Left, 20)
		nav_btns := rc.cut_multiple_evenly_height(&sidebar, 7)
		for &n, i in nav_btns {
			if i == 0 {
				rc.add_padding(&n, 30)
				rc.draw_rect_ui(n, .Secondary, radius = 30, segments = 10)
				rc.draw_text_ui("Button", n, .Main, 70, .Center)
			} else {
				rc.draw_text_ui("Button", n, .Muted, 70, .Center)
			}
		}


		rc.add_padding(&split_wdith[1], 40, .Top)
		rc.add_padding(&split_wdith[1], 40, .Right)
		contents := rc.cut_multiple_top_percent(&split_wdith[1], {0.1, 0.2, 0.5, 0.2})
		for &c in contents {
			rc.add_padding(&c, 40, .Bottom)
		}
		headers := rc.cut_multiple_evenly_width(&contents[0], 2)
		rc.draw_text_ui("Header Text", headers[0], .Main, 70, .Left)
		rc.draw_text_ui("Text", headers[1], .Muted, 70, .Right)

		stats := rc.cut_multiple_evenly_width(&contents[1], 3)
		for &s in stats {
			rc.add_padding(&s, 30, .Right)
			rc.draw_rect_ui(s, .Raised, radius = 30, segments = 10)
			texts := rc.cut_multiple_top_percent(&s, {0.3, 0.4, 0.3})
			rc.draw_text_ui("Text", texts[0], .Muted, 30, .Left, 20)
			rc.draw_text_ui("Main", texts[1], .Main, 70, .Left, 20)
			rc.draw_text_ui("Sub", texts[2], .Muted, 70, .Left, 20)
		}

		rc.add_padding(&contents[2], 30, .Right)
		rc.draw_rect_ui(contents[2], .Raised, radius = 30, segments = 10)
		main_content := rc.cut_multiple_top_percent(&contents[2], {0.2, 0.8})
		main_content_headers := rc.cut_multiple_evenly_width(&main_content[0], 2)
		rc.draw_text_ui("Main Content", main_content[1], .Main, 70, .Center)
		rc.draw_text_ui("Header", main_content_headers[0], .Main, 70, .Center)
		rc.draw_text_ui("Header", main_content_headers[1], .Main, 70, .Center)


		rc.add_padding(&contents[3], 30, .Right)
		footer := rc.cut_multiple_evenly_width(&contents[3], 2)
		footer_btns := rc.cut_multiple_evenly_width(&footer[1], 2)

		rc.add_padding(&footer[0], 30, .Right)
		footer_txt := rc.cut_left_percent(&footer[0], 0.05)
		rc.draw_rect_ui(footer_txt, .Primary)
		rc.draw_rect_ui(footer[0], .Raised)
		rc.draw_text_ui("FooterText", footer[0], .Muted, 70, .Center)

		for &b in footer_btns {
			rc.add_padding(&b, 30, .Right)
			rc.draw_rect_ui(b, .Accent, radius = 30, segments = 10)
			rc.draw_text_ui("Button", b, .Main, 70, .Center)
		}

		rl.EndDrawing()
	}
	rl.CloseWindow()
}
