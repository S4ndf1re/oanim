package oanim

import "core:time"
import "base:runtime"
import "core:dynlib"
import "core:fmt"
import os "core:os/os2"
import "core:slice"
import "core:strings"

when ODIN_OS == .Windows {
	EXTENSION :: ".dll"
} else when ODIN_OS == .Darwin {
	EXTENSION :: ".dylib"
} else {
	EXTENSION :: ".so"
}

PLUGIN_INIT :: "plugin_init"
PLUGIN_UPDATE :: "plugin_update"
PLUGIN_RENDER :: "plugin_render"
PLUGIN_SHUTDOWN :: "plugin_shutdown"
PLUGIN_MEMORY :: "plugin_memory"
PLUGIN_HOT_RELOAD :: "plugin_hot_reload"

// Descriptor of a simple plugin
Plugin :: struct {
	path:       string,
	init:       proc(),
	update:     proc(_: f32),
	render:     proc(),
	shutdown:   proc(),
	memory:     proc() -> rawptr,
	hot_reload: proc(_: rawptr),

	// The loaded library
	lib:        Maybe(dynlib.Library),
	last_time:  Maybe(time.Time),
	loaded:     bool,
}

// Identify all plugins in the root folder
identify_plugins :: proc(
	root: string,
	allocator: runtime.Allocator = context.allocator,
	temp_allocator: runtime.Allocator = context.temp_allocator,
) -> (
	[]Plugin,
	bool,
) {
	files, err := os.read_all_directory_by_path(root, context.allocator)
	if err != nil {
		fmt.printfln("%v", err)
		return nil, false
	}
	defer delete(files)


	plugins := make([dynamic]Plugin, temp_allocator)
	defer delete(plugins)

	for file in files {
		if os.is_dir(file.fullpath) {
			append(&plugins, Plugin{path = file.name})
		}
	}

	return slice.clone(plugins[:]), true
}

load_all_plugins :: proc(plugins: []Plugin) {
	fmt.printf("Reloading plugins\n")
	for i := 0; i < len(plugins); i += 1 {
		load_plugin(&plugins[i])
	}
}

load_plugin :: proc(plugin: ^Plugin) {
	builder := strings.Builder{}
	_, builder_err := strings.builder_init(&builder)
	if builder_err != nil {
		fmt.printf("%v\n", builder_err)
		return
	}
	defer strings.builder_destroy(&builder)

	path := fmt.sbprintf(&builder, "plugins/%s/plugin%s", plugin.path, EXTENSION)
	fmt.printf("Loading lib: %s\n", path)

	last_time, err := os.last_write_time_by_name(path)
	if err != nil {
		return
	}

	if last_time == plugin.last_time {
		return
	}


	fmt.printf("\tReloading %s\n", path)

	lib, ok := dynlib.load_library(path)
	if !ok {
		fmt.println(dynlib.last_error())
		fmt.printf("\tCould not find path: %s\n", path)
		return
	}

	state: rawptr = nil
	if plugin.lib != nil && plugin.memory != nil {
		state = plugin.memory()
	}

	init := cast(proc())(dynlib.symbol_address(lib, PLUGIN_INIT) or_else nil)
	update := cast(proc(_: f32))(dynlib.symbol_address(lib, PLUGIN_UPDATE) or_else nil)
	render := cast(proc())(dynlib.symbol_address(lib, PLUGIN_RENDER) or_else nil)
	shutdown := cast(proc())(dynlib.symbol_address(lib, PLUGIN_SHUTDOWN) or_else nil)
	memory := cast(proc() -> rawptr)(dynlib.symbol_address(lib, PLUGIN_MEMORY) or_else nil)
	hot_reload := cast(proc(_: rawptr))(dynlib.symbol_address(lib, PLUGIN_HOT_RELOAD) or_else nil)

	if init == nil ||
	   update == nil ||
	   shutdown == nil ||
	   memory == nil ||
	   hot_reload == nil ||
	   render == nil {
		plugin.loaded = false
		plugin.lib = nil
		plugin.init = nil
		plugin.update = nil
		plugin.render = nil
		plugin.shutdown = nil
		plugin.memory = nil
		plugin.hot_reload = nil
		plugin.last_time = nil
		fmt.printf("\tFailed to load %s\n", path)
		return
	}

	if state != nil {
		hot_reload(state)
	}

	plugin.init = init
	plugin.update = update
	plugin.render = render
	plugin.shutdown = shutdown
	plugin.memory = memory
	plugin.hot_reload = hot_reload

	plugin.loaded = true
	plugin.lib = lib
	plugin.last_time = last_time
}


init_plugins :: proc(plugins: []Plugin) {
	for plug in plugins {
		if plug.loaded && plug.init != nil {
			plug.init()
            // NOTE: call hot reload here, because that could be used to initialize state
			plug.hot_reload(plug.memory())
		}
	}
}

update_plugins :: proc(plugins: []Plugin, dt: f32) {
	for plug in plugins {
		if plug.loaded && plug.update != nil {
			plug.update(dt)
		}
	}
}

render_plugins :: proc(plugins: []Plugin) {
	for plug in plugins {
		if plug.loaded && plug.render != nil {
			plug.render()
		}
	}
}

shutdown_plugins :: proc(plugins: []Plugin) {
	for plug in plugins {
		if plug.loaded && plug.shutdown != nil {
			plug.shutdown()
		}
	}
}
