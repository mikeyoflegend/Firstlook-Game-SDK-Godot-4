class_name FirstLookSession
extends RefCounted

var _http: FirstLookHttp
var _config: FirstLookConfig
var _session_id: String = ""
var is_active: bool = false

func _init(http: FirstLookHttp, config: FirstLookConfig) -> void:
	_http = http
	_config = config

## Start a new session. Call after successful authentication.
## Returns { success, session_id, error }
func start_session() -> Dictionary:
	var body: Dictionary = { "gameSlug": _config.game_slug }
	if _config.build_version != "":
		body["buildVersion"] = _config.build_version

	var result = await _http.post("/client/v1/sessions", body)

	if not result.success:
		return { "success": false, "error": "Session start failed (HTTP %d)" % result.get("code", 0) }

	_session_id = result.data.get("sessionId", "")
	is_active = true
	print("[FirstLook] Session started: ", _session_id)

	return { "success": true, "session_id": _session_id }

## End the active session. Called automatically on app quit.
func end_session() -> Dictionary:
	if not is_active or _session_id == "":
		return { "success": false, "error": "No active session to end." }

	var result = await _http.post("/client/v1/sessions/" + _session_id + "/end", {})
	is_active = false
	_session_id = ""
	print("[FirstLook] Session ended.")
	return result

func get_session_id() -> String:
	return _session_id
