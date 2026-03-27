package main

import "core:fmt"
import "core:mem"
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
	top_bottom_bars := rc.cut_multiple_top_percent(&layout, {0.1, 0.8, 0.1})
	sidebars_and_center := rc.cut_multiple_left_percent(&top_bottom_bars[1], {0.1, 0.8, 0.1})
	defer delete(top_bottom_bars)
	defer delete(sidebars_and_center)

	fmt.println(top_bottom_bars[2])

	UI_CONTENT = UiContent {
		top_banner    = top_bottom_bars[0],
		left_sidebar  = sidebars_and_center[0],
		center        = sidebars_and_center[1],
		right_sidebar = sidebars_and_center[2],
		bottom_banner = top_bottom_bars[2],
	}
}

main :: proc() {
	tracking_allocator: mem.Tracking_Allocator
	mem.tracking_allocator_init(&tracking_allocator, context.allocator)
	defer mem.tracking_allocator_destroy(&tracking_allocator)
	context.allocator = mem.tracking_allocator(&tracking_allocator)
	defer {
		fmt.printfln("MEMORY SUMMARY")
		for _, leak in tracking_allocator.allocation_map {
			fmt.printfln(" %v leaked %m", leak.location, leak.size)
		}
		for bad_free in tracking_allocator.bad_free_array {
			fmt.printfln(" %v allocation %p was freed badly", bad_free.location, bad_free.memory)
		}
	}


	rl.InitWindow(0, 0, "Crop Clicker")
	rl.SetTargetFPS(60)
	rl.ToggleBorderlessWindowed()

	font := rl.LoadFont("Roboto-VariableFont_wdth,wght.ttf")
	rc.init_font(font)

	SCREEN_SIZE.width = f32(rl.GetRenderWidth())
	SCREEN_SIZE.height = f32(rl.GetRenderHeight())

	ui_initial_setup()

	rc.init_ui_colours(
		text = rl.Color{240, 231, 227, 255},
		background = rl.Color{66, 57, 52, 255},
		primary = rl.Color{220, 172, 146, 255},
		secondary = rl.Color{130, 65, 31, 255},
		accent = rl.Color{220, 103, 40, 255},
	)

	for !rl.WindowShouldClose() {
		rl.BeginDrawing()
		rl.ClearBackground(rl.WHITE)

		rc.draw_rect_ui(UI_CONTENT.center, .Background, 30)
		center := UI_CONTENT.center
		rc.add_padding(&center, 20)
		split_wdith := rc.cut_multiple_left_percent(&center, {0.3, 0.7})
		defer delete(split_wdith)
		sidebar := split_wdith[0]
		rc.add_padding(&sidebar, 40)
		rc.draw_rect_ui(sidebar, .Sunken, 30)

		sidebar_header := rc.cut_top_percent(&sidebar, 0.1)
		rc.draw_text_ui("Sidebar Header", sidebar_header, .Muted, 50, .Left, 20)
		nav_btns := rc.cut_multiple_evenly_height(&sidebar, 7)
		defer delete(nav_btns)
		for &n, i in nav_btns {
			if i == 0 {
				rc.add_padding(&n, 30)
				rc.draw_rect_ui(n, .Secondary, 30, 10)
				rc.draw_text_ui("Button", n, .Main, 70, .Center)
			} else {
				rc.draw_text_ui("Button", n, .Muted, 70, .Center)
			}
		}


		rc.add_padding(&split_wdith[1], 40, .Top)
		rc.add_padding(&split_wdith[1], 40, .Right)
		contents := rc.cut_multiple_top_percent(&split_wdith[1], {0.1, 0.2, 0.5, 0.2})
		defer delete(contents)
		for &c, i in contents {
			rc.add_padding(&c, 40, .Bottom)
		}
		headers := rc.cut_multiple_evenly_width(&contents[0], 2)
		defer delete(headers)
		rc.draw_text_ui("Header Text", headers[0], .Main, 70, .Left)
		rc.draw_text_ui("Text", headers[1], .Muted, 70, .Right)

		stats := rc.cut_multiple_evenly_width(&contents[1], 3)
		defer delete(stats)
		for &s, _ in stats {
			rc.add_padding(&s, 30, .Right)
			rc.draw_rect_ui(s, .Raised, 30, 10)
			texts := rc.cut_multiple_top_percent(&s, {0.3, 0.4, 0.3})
			defer delete(texts)
			rc.draw_text_ui("Text", texts[0], .Muted, 30, .Left, 20)
			rc.draw_text_ui("Main", texts[1], .Main, 70, .Left, 20)
			rc.draw_text_ui("Sub", texts[2], .Muted, 70, .Left, 20)
		}

		rc.add_padding(&contents[2], 30, .Right)
		rc.draw_rect_ui(contents[2], .Raised, 30, 10)
		main_content := rc.cut_multiple_top_percent(&contents[2], {0.2, 0.8})
		defer delete(main_content)
		main_content_headers := rc.cut_multiple_evenly_width(&main_content[0], 2)
		defer delete(main_content_headers)
		rc.draw_text_ui("Main Content", main_content[1], .Main, 70, .Center)
		rc.draw_text_ui("Header", main_content_headers[0], .Main, 70, .Center)
		rc.draw_text_ui("Header", main_content_headers[1], .Main, 70, .Center)


		rc.add_padding(&contents[3], 30, .Right)
		footer := rc.cut_multiple_evenly_width(&contents[3], 2)
		defer delete(footer)
		footer_btns := rc.cut_multiple_evenly_width(&footer[1], 2)

		rc.add_padding(&footer[0], 30, .Right)
		footer_txt := rc.cut_left_percent(&footer[0], 0.05)
		rc.draw_rect_ui(footer_txt, .Primary)
		rc.draw_rect_ui(footer[0], .Raised)
		rc.draw_text_ui("FooterText", footer[0], .Muted, 70, .Center)

		defer delete(footer_btns)
		for &b in footer_btns {
			rc.add_padding(&b, 30, .Right)
			rc.draw_rect_ui(b, .Accent, 30, 10)
			rc.draw_text_ui("Button", b, .Main, 70, .Center)
		}


		rl.EndDrawing()
	}
	rl.UnloadFont(font)
	rl.CloseWindow()
}
