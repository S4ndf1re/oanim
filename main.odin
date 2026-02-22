package oanim

import rl "vendor:raylib"

main :: proc() {
	plugins, ok := identify_plugins("plugins/")
	if !ok {
		return
	}
	defer delete(plugins)

	factor := 50.0
	rl.InitWindow((i32)(16.0 * factor), (i32)(9.0 * factor), "oanim")
	defer rl.CloseWindow()
	rl.SetTargetFPS(60)
	rl.SetWindowState({.WINDOW_TOPMOST})

	// Plugin loading
	load_all_plugins(plugins)
	init_plugins(plugins)

	bg_texture := rl.LoadRenderTexture((i32)(16.0 * factor), (i32)(9.0 * factor))
	defer rl.UnloadRenderTexture(bg_texture)

	for !rl.WindowShouldClose() {
		rl.ClearBackground(rl.BLACK)
		update_plugins(plugins, rl.GetFrameTime())

		rl.BeginTextureMode(bg_texture)
		{
			rl.ClearBackground(rl.BLACK)
			render_plugins(plugins)
		}
		rl.EndTextureMode()

		rl.BeginDrawing()
		{
			rl.ClearBackground(rl.BLACK)
			render_plugins(plugins)
		}
		rl.EndDrawing()

		// Hot reload
		if rl.IsKeyReleased(rl.KeyboardKey.R) {
			load_all_plugins(plugins)
		}
	}

	shutdown_plugins(plugins)
}
