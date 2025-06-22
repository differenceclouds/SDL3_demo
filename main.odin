package main

import "base:runtime"
import "core:log"
import sdl "vendor:sdl3"

default_context: runtime.Context

frag_shader_code := #load("shader_frag.metal")
vert_shader_code := #load("shader_vert.metal")
// frag_shader_code := #load("shader.glsl.frag")
// vert_shader_code := #load("shader.glsl.vert")

Device :: struct {
	gpu: ^sdl.GPUDevice,
	window: ^sdl.Window,
	pipeline: ^sdl.GPUGraphicsPipeline
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

	device : Device

	device.window = sdl.CreateWindow("Hello SDL3", 1280, 720, {.RESIZABLE}); assert(device.window != nil)
	device.gpu = sdl.CreateGPUDevice({.MSL}, true, nil)

	ok = sdl.ClaimWindowForGPUDevice(device.gpu, device.window); assert(ok)

	vert_shader := load_shader(device.gpu, vert_shader_code, .VERTEX)
	frag_shader := load_shader(device.gpu, frag_shader_code, .FRAGMENT)

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

	ok = sdl.AddEventWatch(proc "c" (userdata: rawptr, event: ^sdl.Event) -> bool {
		if event.type == .WINDOW_EXPOSED {
			context = default_context
			device := cast(^Device)userdata
			draw(device)
		}
		return true
	}, &device); assert(ok)

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

draw :: proc(device: ^Device) {
	using device
	cmd_buf := sdl.AcquireGPUCommandBuffer(gpu)
	swapchain_tex : ^sdl.GPUTexture
	ok := sdl.WaitAndAcquireGPUSwapchainTexture(cmd_buf, window, &swapchain_tex, nil, nil); assert(ok)
	if swapchain_tex != nil {
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
		ok = sdl.SubmitGPUCommandBuffer(cmd_buf); assert(ok)
	}
}