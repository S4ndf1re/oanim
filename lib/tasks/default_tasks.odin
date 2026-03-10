package tasks

import lib ".."
import "base:runtime"
import "core:time"

WaitTaskState :: struct {
	wait_time_seconds: f64,
	stopwatch:         time.Stopwatch,
	allocator:         runtime.Allocator,
}

new_wait_task :: proc(wait_time_seconds: f64, allocator := context.allocator) -> Task {
	state := new(WaitTaskState, allocator)
	state.wait_time_seconds = wait_time_seconds
	state.stopwatch = time.Stopwatch{}
	state.allocator = allocator

	return init_task(state, advance_wait, cleanup_wait, restart_wait)
}


advance_wait :: proc(state: rawptr) -> bool {
	wait_state := cast(^WaitTaskState)state

	if !wait_state.stopwatch.running {
		time.stopwatch_start(&wait_state.stopwatch)
	}

	elapsed_time := time.stopwatch_duration(wait_state.stopwatch)

	elapsed_seconds := time.duration_seconds(elapsed_time)

	if elapsed_seconds >= wait_state.wait_time_seconds {
		time.stopwatch_stop(&wait_state.stopwatch)
		return true
	}

	return false
}


cleanup_wait :: proc(ptr: rawptr) {
	wait_state := cast(^WaitTaskState)ptr
	free(wait_state, wait_state.allocator)
}

restart_wait :: proc(ptr: rawptr) {
	wait_state := cast(^WaitTaskState)ptr
	wait_state.stopwatch = time.Stopwatch{}
}


KeyframeTaskCallback :: #type proc(state: rawptr, keyframe_value: f32)

KeyframeTaskState :: struct {
	state:     rawptr,
	callback:  KeyframeTaskCallback,
	stopwatch: time.Stopwatch,
	frames:    lib.Keyframes,
	allocator: runtime.Allocator,
}

new_keyframe_task :: proc(
	keyframes: lib.Keyframes,
	state: rawptr,
	callback: KeyframeTaskCallback,
	allocator := context.allocator,
) -> Task {
	key_state := new(KeyframeTaskState, allocator)
	key_state.frames = keyframes
	key_state.allocator = allocator
	key_state.callback = callback
	key_state.state = state
	key_state.stopwatch = time.Stopwatch{}

	return init_task(key_state, advance_keyframes, cleanup_keyframes, restart_keyframes)
}


advance_keyframes :: proc(ptr: rawptr) -> bool {
	keyframe_state := cast(^KeyframeTaskState)ptr

	if !keyframe_state.stopwatch.running {
		time.stopwatch_start(&keyframe_state.stopwatch)
	}

	elapsed := time.stopwatch_duration(keyframe_state.stopwatch)
	done := lib.advance_single((f32)(time.duration_seconds(elapsed)), &keyframe_state.frames)

	if keyframe_state.callback != nil {
		keyframe_state.callback(keyframe_state.state, lib.get_value(&keyframe_state.frames))
	}

	// Restart the stopwatch
	time.stopwatch_reset(&keyframe_state.stopwatch)
	time.stopwatch_start(&keyframe_state.stopwatch)

	return done
}


cleanup_keyframes :: proc(ptr: rawptr) {
	keyframes_state := cast(^KeyframeTaskState)ptr

	lib.destroy_keyframes(&keyframes_state.frames)

	free(keyframes_state, keyframes_state.allocator)
}

restart_keyframes :: proc(ptr: rawptr) {
	keyframes_state := cast(^KeyframeTaskState)ptr

	lib.restart_keyframes(&keyframes_state.frames)
	keyframes_state.stopwatch = time.Stopwatch{}

}
