class_name PlaytestRecorder
extends RefCounted
## Replay evidence includes actual states; elapsed time is observational only.

var enabled := true
var output_dir := "user://playtests"
var path := ""
var report: Dictionary = {}
var started_at := 0
var write_error := false

func begin(metadata: Dictionary, initial: Dictionary) -> void:
	started_at = Time.get_ticks_msec()
	report = {"schema": 1, "metadata": metadata.duplicate(true), "initial": initial.duplicate(true), "events": []}
	path = "%s/run_%d_%d.json" % [output_dir, Time.get_unix_time_from_system(), Time.get_ticks_usec()]
	flush()

func record(action: String, before: Dictionary, after: Dictionary, details: Dictionary) -> void:
	if not enabled:
		return
	report.events.append({"step": report.events.size() + 1, "action": action, "elapsed_ms": Time.get_ticks_msec() - started_at, "before": before.duplicate(true), "after": after.duplicate(true), "details": details.duplicate(true)})
	flush()

func flush() -> void:
	if not enabled or path.is_empty():
		return
	write_error = DirAccess.make_dir_recursive_absolute(output_dir) != OK
	if write_error:
		return
	var file := FileAccess.open(path, FileAccess.WRITE)
	write_error = file == null
	if file != null:
		file.store_string(JSON.stringify(report, "\t"))
