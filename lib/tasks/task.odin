package tasks

// This callback will get called until the callback is finished, ie. returns true
TaskCallback :: #type proc(state: rawptr) -> bool

TaskCleanup :: #type proc(state: rawptr)

TaskRestart :: #type proc(state: rawptr)

// Defines a simple task
Task :: struct {
	_state:    rawptr,
	_callback: TaskCallback,
	_restart:  TaskRestart,
	_cleanup:  TaskCleanup,
	is_done:   bool,
}

init_task :: proc(
	state: rawptr,
	callback: TaskCallback,
	cleanup: TaskCleanup,
	restart: TaskRestart,
) -> Task {
	task := Task{}
	task._state = state
	task._callback = callback
	task._cleanup = cleanup
	task._restart = restart
	return task
}

destroy_task :: proc(task: ^Task) {
	if task._cleanup != nil {
		task._cleanup(task._state)
		task._state = nil
	}
}

// Update a single task, including all subtasks sequentially
update_task :: proc(task: ^Task, ignore_done := false) -> bool {
	if task.is_done && !ignore_done {
		return task.is_done
	}

	task.is_done = task._callback == nil || task._callback(task._state)

	return task.is_done
}

restart_task :: proc(task: ^Task) {
	task.is_done = false
	if task._restart != nil {
		task._restart(task._state)
	}
}
