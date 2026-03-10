package oanim

import "base:runtime"
import "core:fmt"
import "core:math"
import "core:os/os2"
import rl "vendor:raylib"
import "vendor:raylib/rlgl"

main :: proc() {
	cwd, cwd_err := os2.get_executable_directory(context.allocator)
	if cwd_err != nil {
		fmt.println(cwd_err)
		return
	}
	defer delete(cwd)

	plugins, ok := identify_plugins("plugins/")
	if !ok {
		return
	}
	defer delete(plugins)

	factor: f32 = 50.0
    rl.SetConfigFlags({.WINDOW_HIGHDPI, .MSAA_4X_HINT})
	rl.InitWindow((i32)(16.0 * factor), (i32)(9.0 * factor), "oanim")
	defer rl.CloseWindow()
	rl.SetTargetFPS(60)
	rl.SetWindowState({.WINDOW_TOPMOST})


	setup_camera :: proc(camera: ^rl.Camera3D) {
		camera.fovy = 45.0
		camera.position = {
			(f32)(rl.GetScreenWidth()) / 2.0,
			(f32)(rl.GetScreenHeight()) / 2.0,
			math.tan(math.to_radians((180.0 - camera.fovy) / 2.0)) *
			-((f32)(rl.GetScreenHeight()) / 2.0),
		}
		camera.target = {(f32)(rl.GetScreenWidth()) / 2.0, (f32)(rl.GetScreenHeight()) / 2.0, 0.0}
		camera.up = {0.0, 1.0, 0.0}
		camera.projection = .PERSPECTIVE
	}

	camera := rl.Camera3D{}
	setup_camera(&camera)

	// Plugin loading
	load_all_plugins(plugins)
	init_plugins(plugins)


	bg_texture := rl.LoadRenderTexture((i32)(16.0 * factor), (i32)(9.0 * factor))
	defer rl.UnloadRenderTexture(bg_texture)

	for !rl.WindowShouldClose() {
		rl.UpdateCamera(&camera, .THIRD_PERSON)

		update_plugins(plugins, rl.GetFrameTime())

		rl.BeginDrawing()
		{
			rl.ClearBackground(rl.BLACK)
			rl.BeginMode3D(camera)
			{
				// rl.BeginTextureMode(bg_texture)
				// {
				// 	rl.ClearBackground(rl.BLACK)
				// 	render_plugins(plugins)
				// }
				// rl.EndTextureMode()

				rl.DrawCube({0.0, 0.0, 0.0}, 100.0, 100.0, 100.0, rl.RED)
				render_plugins(plugins)
				rlgl.DrawRenderBatchActive()
			}
			rl.EndMode3D()
		}
		rl.EndDrawing()

		// Hot reload
		if rl.IsKeyReleased(rl.KeyboardKey.R) {
			load_all_plugins(plugins)
		} else if rl.IsKeyReleased(.F) {
			setup_camera(&camera)
		}

	}

	shutdown_plugins(plugins)
}
