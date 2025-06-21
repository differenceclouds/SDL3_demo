package main

import "base:runtime"
import "core:log"
import sdl "vendor:sdl3"

default_context: runtime.Context

frag_shader_code := #load("shader_frag.metal")
vert_shader_code := #load("shader_vert.metal")


main :: proc() {
	context.logger = log.create_console_logger()
	default_context = context

	sdl.SetLogPriorities(.VERBOSE)
	sdl.SetLogOutputFunction(proc "c" (userdata: rawptr, category: sdl.LogCategory, priority: sdl.LogPriority, message: cstring) {
		context = default_context
		log.debugf("SDL {} [{}]: {}", category, priority, message)
	}, nil)

	ok: bool

	ok = sdl.Init({.VIDEO}); assert(ok)

	window := sdl.CreateWindow("Hello SDL3", 1280, 720, {}); assert(window != nil)

	gpu := sdl.CreateGPUDevice({.MSL}, true, nil)

	ok = sdl.ClaimWindowForGPUDevice(gpu, window); assert(ok)

	vert_shader := load_shader(gpu, vert_shader_code, .VERTEX)
	frag_shader := load_shader(gpu, frag_shader_code, .FRAGMENT)

	pipeline := sdl.CreateGPUGraphicsPipeline(gpu, {
		vertex_shader = vert_shader,
		fragment_shader = frag_shader,
		primitive_type = .TRIANGLELIST,
		target_info = {
			num_color_targets = 1,
			color_target_descriptions = &(sdl.GPUColorTargetDescription {
				format = sdl.GetGPUSwapchainTextureFormat(gpu, window)
			})
		}
	})

	sdl.ReleaseGPUShader(gpu, vert_shader)
	sdl.ReleaseGPUShader(gpu, frag_shader)

	main_loop: for {
		ev: sdl.Event
		for sdl.PollEvent(&ev) {
			#partial switch ev.type {
				case .QUIT:
					break main_loop
				case .KEY_DOWN:
					if ev.key.scancode == .ESCAPE do break main_loop
			}
		}

		// update game state

		// render
		cmd_buf := sdl.AcquireGPUCommandBuffer(gpu)
		
		swapchain_tex : ^sdl.GPUTexture
		ok = sdl.WaitAndAcquireGPUSwapchainTexture(cmd_buf, window, &swapchain_tex, nil, nil); assert(ok)

		color_target := sdl.GPUColorTargetInfo {
			texture = swapchain_tex,
			load_op = .CLEAR,
			clear_color = {0, 0.2, 0.4, 1},
			store_op = .STORE,

		}
		render_pass := sdl.BeginGPURenderPass(cmd_buf, &color_target, 1, nil)
		sdl.BindGPUGraphicsPipeline(render_pass, pipeline)
		sdl.DrawGPUPrimitives(render_pass, 3, 1, 0, 0)

		sdl.EndGPURenderPass(render_pass)

		// more render passes
		
		ok = sdl.SubmitGPUCommandBuffer(cmd_buf); assert(ok)
	}
}

load_shader :: proc(device: ^sdl.GPUDevice, code: []u8, stage: sdl.GPUShaderStage) -> ^sdl.GPUShader {
	entrypoint_string: cstring
	switch stage {
		case .FRAGMENT: entrypoint_string = "fragment_main"
		case .VERTEX: entrypoint_string = "vertex_main"
	}
	return sdl.CreateGPUShader(device, {
		code_size = len(code),
		code = raw_data(code),
		entrypoint = entrypoint_string,
		format = {.MSL},
		stage = stage
	})
}