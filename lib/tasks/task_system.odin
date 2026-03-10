package tasks

import "core:fmt"

// Defines a list of tasks
TaskSystem :: struct {
	is_done:                         bool,
	// Loop after completion, starting at front
	loop:                            bool,
	// Do not change any state, just set the is_done flag to false
	dont_change_progress_on_restart: bool,
	// Clear the task queue, once the is_done flag is set to ture, except when the loop flag is on
	clear_when_done:                 bool,
	// Trigger task callbacks even after reaching done for a task, until all tasks are finished
	trigger_callback_after_done:     bool,
	_current_task_idx:               int,
	_tasks:                          [dynamic]Task,
}

init_system :: proc(sys: ^TaskSystem, allocator := context.allocator) {
	sys._tasks = make([dynamic]Task, allocator)
}

destroy_system :: proc(sys: ^TaskSystem) {
	if sys._tasks != nil {
		for _, i in sys._tasks {
			destroy_task(&sys._tasks[i])
		}
		delete(sys._tasks)
		sys._tasks = nil
	}
}

// Add a new task, setting is_done to false, as a new task was added and the system is inherently not done
add_task :: proc(sys: ^TaskSystem, task: Task) {
	append(&sys._tasks, task)
	sys.is_done = false
}


@(private)
are_tasks_done :: proc(sys: ^TaskSystem) -> bool {
	return sys._current_task_idx >= len(sys._tasks)
}

// Update a TaskSystem
update_system :: proc(sys: ^TaskSystem) -> bool {
	if is_system_done(sys) && !sys.trigger_callback_after_done {
		return sys.is_done
	}

	if sys.is_done && sys.loop {
		restart_system(sys)
	}

	if !are_tasks_done(sys) {
		if sys.trigger_callback_after_done {
			for i in 0 ..< sys._current_task_idx {
				finished_task := &sys._tasks[i]
				update_task(finished_task, ignore_done = true)
			}
		}
		current_task := &sys._tasks[sys._current_task_idx]
		if update_task(current_task) {
			sys._current_task_idx += 1
		}
	}


	if are_tasks_done(sys) {
		sys.is_done = true
		if sys.clear_when_done && !sys.loop {
			clear(&sys._tasks)
		}
	}

	return is_system_done(sys)
}

is_system_done :: proc(sys: ^TaskSystem) -> bool {
	return sys.is_done && !sys.loop
}

restart_system :: proc(sys: ^TaskSystem) {
	if !sys.dont_change_progress_on_restart {
		for _, i in sys._tasks {
			restart_task(&sys._tasks[i])
		}

		sys._current_task_idx = 0
	}

	sys.is_done = false
}
