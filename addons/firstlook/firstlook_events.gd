class_name FirstLookEvents
extends RefCounted

## Counter and duration analytics events.
## Endpoints:
##   POST /client/v0/analytics/counter_event
##   POST /client/v1/analytics/duration_event_start
##   POST /client/v1/analytics/duration_event_end
##
## Naming: use "<category>.<event-type>", for example "match.win".
## The "firstlook" namespace is reserved for built-in events.

const MAX_PARAM_LENGTH := 64

var _http: FirstLookHttp
var _session: FirstLookSession
var _config: FirstLookConfig
var _open_durations: Dictionary = {}

func _init(http: FirstLookHttp, session: FirstLookSession, config: FirstLookConfig) -> void:
	_http = http
	_session = session
	_config = config

## Count something that happened.
##   post_counter_event("match.win")
##   post_counter_event("level.started", 1, "forest_3")
## A param is stored as "level.started#forest_3" and also adds to the
## "level.started" total. Keep the set of param values small.
func post_counter_event(event_name: String, count: int = 1, param: String = "") -> Dictionary:
	var check := _validate(event_name, "post_counter_event")
	if not check.success:
		return check

	var body := {
		"session_id": _session.get_session_id(),
		"counter_name": event_name,
		"count": count,
		"timestamp": FirstLookHttp.timestamp(),
	}
	var clean_param := param.strip_edges().to_lower()
	if clean_param != "":
		if clean_param.contains("#"):
			return _warn("Counter param cannot contain '#': " + param)
		if clean_param.length() > MAX_PARAM_LENGTH:
			return _warn("Counter param is longer than %d characters: %s" % [MAX_PARAM_LENGTH, param])
		body["param"] = clean_param
	_add_build(body)

	return await _http.post("/client/v0/analytics/counter_event", body)

## Start timing something. Call end_duration_event() with the same name
## when it finishes. A duration that never ends is left out of totals.
func start_duration_event(event_name: String) -> Dictionary:
	var check := _validate(event_name, "start_duration_event")
	if not check.success:
		return check
	if _open_durations.has(event_name):
		return _warn("Duration event already running: " + event_name)

	_open_durations[event_name] = true
	var body := {
		"session_id": _session.get_session_id(),
		"duration_name": event_name,
		"timestamp": FirstLookHttp.timestamp(),
	}
	_add_build(body)
	var result := await _http.post("/client/v1/analytics/duration_event_start", body)
	if not result.success:
		_open_durations.erase(event_name)
	return result

func end_duration_event(event_name: String) -> Dictionary:
	var check := _validate(event_name, "end_duration_event")
	if not check.success:
		return check
	if not _open_durations.has(event_name):
		return _warn("No running duration event named: " + event_name)

	_open_durations.erase(event_name)
	return await _http.post("/client/v1/analytics/duration_event_end", {
		"session_id": _session.get_session_id(),
		"duration_name": event_name,
		"timestamp": FirstLookHttp.timestamp(),
	})

func is_duration_running(event_name: String) -> bool:
	return _open_durations.has(event_name)

## Ends every running duration. Called automatically before the session ends.
func end_all_durations() -> void:
	for event_name in _open_durations.keys():
		await end_duration_event(event_name)

func _validate(event_name: String, caller: String) -> Dictionary:
	if not _session.is_active:
		return _warn("%s skipped: FirstLook is not ready yet (no active session)." % caller)
	if event_name.strip_edges() == "":
		return _warn("%s needs an event name." % caller)
	if event_name.begins_with("firstlook."):
		return _warn("The 'firstlook' event namespace is reserved: " + event_name)
	return { "success": true }

func _add_build(body: Dictionary) -> void:
	var build := FirstLookSession.resolve_build_version(_config)
	if build != "":
		body["build_version"] = build

func _warn(message: String) -> Dictionary:
	push_warning("[FirstLook] " + message)
	return { "success": false, "code": 0, "data": {}, "error": message }
