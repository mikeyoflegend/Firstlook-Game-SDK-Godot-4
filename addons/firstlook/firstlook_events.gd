class_name FirstLookEvents
extends RefCounted

# Event names follow the "category.event-type" convention.
# Examples: "match.round-started", "loadout.hero-selected", "store.item-purchased"
# The "firstlook" namespace is reserved. Do not use it for custom events.

var _http: FirstLookHttp
var _session: FirstLookSession
var _open_durations: Dictionary = {}

func _init(http: FirstLookHttp, session: FirstLookSession) -> void:
	_http = http
	_session = session

## Send a named counter event with an integer value.
## event_name should follow "category.event-type" e.g. "match.win"
func post_counter_event(event_name: String, value: int = 1) -> Dictionary:
	if not _session.is_active:
		push_warning("[FirstLook] post_counter_event called with no active session.")
		return { "success": false, "error": "No active session." }

	return await _http.post("/client/v1/events/counter", {
		"sessionId": _session.get_session_id(),
		"eventName": event_name,
		"value": value
	})

## Begin a timed duration event. Call end_duration_event() when the activity finishes.
## event_name should follow "category.event-type" e.g. "match.round"
func start_duration_event(event_name: String) -> Dictionary:
	if not _session.is_active:
		push_warning("[FirstLook] start_duration_event called with no active session.")
		return { "success": false, "error": "No active session." }

	if _open_durations.has(event_name):
		push_warning("[FirstLook] Duration event already open: " + event_name)
		return { "success": false, "error": "Duration event already open: " + event_name }

	var result = await _http.post("/client/v1/events/duration/start", {
		"sessionId": _session.get_session_id(),
		"eventName": event_name
	})

	if result.success:
		_open_durations[event_name] = result.data.get("durationEventId", "")

	return result

## End a previously started duration event.
func end_duration_event(event_name: String) -> Dictionary:
	if not _session.is_active:
		push_warning("[FirstLook] end_duration_event called with no active session.")
		return { "success": false, "error": "No active session." }

	if not _open_durations.has(event_name):
		push_warning("[FirstLook] No open duration event found for: " + event_name)
		return { "success": false, "error": "No open duration event: " + event_name }

	var duration_id: String = _open_durations[event_name]
	_open_durations.erase(event_name)

	return await _http.post("/client/v1/events/duration/" + duration_id + "/end", {
		"sessionId": _session.get_session_id()
	})
