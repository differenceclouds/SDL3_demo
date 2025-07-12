package main

import "base:runtime"
import "core:log"
import "core:math/linalg"
import sdl "vendor:sdl3"

default_context: runtime.Context

frag_shader_code := #load("shader_frag.metal")
vert_shader_code := #load("shader_vert.metal")
// frag_shader_code := #load("shader.spv.frag")
// vert_shader_code := #load("shader.spv.vert")

SDL_Data :: struct {
	gpu: ^sdl.GPUDevice,
	window: ^sdl.Window,
	pipeline: ^sdl.GPUGraphicsPipeline,
	ubo: UBO
}

UBO :: struct {
	proj: matrix[4,4]f32
}

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

	device : SDL_Data
	shader_format: sdl.GPUShaderFormat = {.MSL}

	device.window = sdl.CreateWindow("Hello SDL3", 1280, 720, {.RESIZABLE}); assert(device.window != nil)
	device.gpu = sdl.CreateGPUDevice(shader_format, true, nil)

	ok = sdl.ClaimWindowForGPUDevice(device.gpu, device.window); assert(ok)

	vert_shader := load_shader(device.gpu, shader_format, vert_shader_code, .VERTEX, 1)
	frag_shader := load_shader(device.gpu, shader_format, frag_shader_code, .FRAGMENT, 0)

	// window2 := sdl.CreateWindow("AUXILIARY WINDOW", 300, 300, {.RESIZABLE})

	device.pipeline = sdl.CreateGPUGraphicsPipeline(device.gpu, {
		vertex_shader = vert_shader,
		fragment_shader = frag_shader,
		primitive_type = .TRIANGLELIST,
		target_info = {
			num_color_targets = 1,
			color_target_descriptions = &(sdl.GPUColorTargetDescription {
				format = sdl.GetGPUSwapchainTextureFormat(device.gpu, device.window)
			})
		}
	})

	sdl.ReleaseGPUShader(device.gpu, vert_shader)
	sdl.ReleaseGPUShader(device.gpu, frag_shader)

	//Do draw calls continuously if the window is being resized
	ok = sdl.AddEventWatch(proc "c" (userdata: rawptr, event: ^sdl.Event) -> bool {
		if event.type == .WINDOW_EXPOSED {
			context = default_context
			device := cast(^SDL_Data)userdata
			draw(device)
		}
		return true
	}, &device); assert(ok)

	win_size : [2]i32
	ok = sdl.GetWindowSize(device.window, &win_size.x, &win_size.y); assert(ok)
	aspect := f32(win_size.x) / f32(win_size.y)
	device.ubo.proj = linalg.matrix4_perspective_f32(70, aspect, 0.0001, 1000)

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
		draw(&device)
	}
}

load_shader :: proc(device: ^sdl.GPUDevice, shader_format: sdl.GPUShaderFormat, code: []u8, stage: sdl.GPUShaderStage, num_uniform_buffers:u32) -> ^sdl.GPUShader {
	entrypoint_string: cstring = "main"
	if shader_format == {.MSL} {
		switch stage {
			case .FRAGMENT: entrypoint_string = "fragment_main"
			case .VERTEX: entrypoint_string = "vertex_main"
		}
	}
	return sdl.CreateGPUShader(device, {
		code_size = len(code),
		code = raw_data(code),
		entrypoint = entrypoint_string,
		format = shader_format,
		stage = stage,
		num_uniform_buffers = num_uniform_buffers,
	})
}

draw :: proc(device: ^SDL_Data) {
	cmd_buf := sdl.AcquireGPUCommandBuffer(device.gpu)
	swapchain_tex : ^sdl.GPUTexture
	ok := sdl.WaitAndAcquireGPUSwapchainTexture(cmd_buf, device.window, &swapchain_tex, nil, nil); assert(ok)

	ubo := device.ubo.proj

	if swapchain_tex != nil {
		color_target := sdl.GPUColorTargetInfo {
			texture = swapchain_tex,
			load_op = .CLEAR,
			clear_color = {0, 0.2, 0.4, 1},
			store_op = .STORE,
		}
		render_pass := sdl.BeginGPURenderPass(cmd_buf, &color_target, 1, nil)
		sdl.BindGPUGraphicsPipeline(render_pass, device.pipeline)

		sdl.PushGPUVertexUniformData(cmd_buf, 0, &ubo, size_of(ubo))

		sdl.DrawGPUPrimitives(render_pass, 3, 1, 0, 0)
		sdl.EndGPURenderPass(render_pass)
		ok = sdl.SubmitGPUCommandBuffer(cmd_buf); assert(ok)
	}
}