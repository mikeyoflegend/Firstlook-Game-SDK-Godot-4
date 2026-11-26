class_name FirstLookAuth
extends RefCounted

## Signs the player in to FirstLook. Uses Steam when GodotSteam is present
## and running, and can fall back to an anonymous ID.
##
## GodotSteam is looked up at runtime, so this script compiles and runs
## fine in projects that do not have GodotSteam installed.
## Endpoint: POST /client/v1/auth

const ANON_ID_PATH := "user://firstlook_anon_id.cfg"
const TICKET_WAIT_SECONDS := 3.0

var _http: FirstLookHttp
var _config: FirstLookConfig
var _host: Node
var _ticket_handle: int = 0

## "steam", "anonymous", or "" if not signed in yet.
var method: String = ""

func _init(http: FirstLookHttp, config: FirstLookConfig, host: Node) -> void:
	_http = http
	_config = config
	_host = host

## Returns { success, method, error }
func authenticate() -> Dictionary:
	var steam_error := ""
	if _config.use_steam:
		var steam_result := await authenticate_steam()
		if steam_result.success:
			return steam_result
		steam_error = steam_result.error
		if _config.allow_anonymous:
			print("[FirstLook] Steam login unavailable (%s). Signing in anonymously." % steam_error)

	if _config.allow_anonymous:
		return await authenticate_anonymous()

	return { "success": false, "method": "", "error": steam_error if steam_error != "" else "No login method enabled in FirstLookConfig." }

func authenticate_steam() -> Dictionary:
	var steam: Object = get_steam()
	if steam == null:
		return _fail("GodotSteam is not installed")
	if not steam.call("isSteamRunning"):
		return _fail("Steam is not running")

	var ticket_info: Variant = steam.call("getAuthSessionTicket")
	var buffer := PackedByteArray()
	if ticket_info is Dictionary:
		_ticket_handle = int(ticket_info.get("id", 0))
		buffer = ticket_info.get("buffer", PackedByteArray())
		var size: int = int(ticket_info.get("size", buffer.size()))
		if size > 0 and size < buffer.size():
			buffer = buffer.slice(0, size)
	elif ticket_info is PackedByteArray:
		buffer = ticket_info

	if buffer.is_empty():
		return _fail("Could not get a Steam session ticket. Is Steam logged in?")

	# Steam says a ticket is only valid after this callback arrives.
	# It needs Steam callbacks running (Steam.run_callbacks() each frame,
	# or GodotSteam's embedded callbacks setting). We wait a short time,
	# then continue either way.
	await _wait_for_ticket(steam)

	var app_id: int = int(steam.call("getAppID"))
	var result := await _http.post("/client/v1/auth", {
		"game_slug": _config.game_slug,
		"ticket": buffer.hex_encode(),
		"app_id": app_id,
	})
	return _finish(result, "steam")

func authenticate_anonymous() -> Dictionary:
	var result := await _http.post("/client/v1/auth", {
		"game_slug": _config.game_slug,
		"anon_id": _get_or_create_anon_id(),
	})
	return _finish(result, "anonymous")

## Releases the Steam ticket. Called when the session ends.
func release() -> void:
	var steam: Object = get_steam()
	if steam != null and _ticket_handle != 0 and steam.has_method("cancelAuthTicket"):
		steam.call("cancelAuthTicket", _ticket_handle)
	_ticket_handle = 0

static func get_steam() -> Object:
	if Engine.has_singleton("Steam"):
		return Engine.get_singleton("Steam")
	return null

func _wait_for_ticket(steam: Object) -> void:
	if not steam.has_signal("get_auth_session_ticket_response"):
		return
	var state := { "done": false }
	var on_response := func(_handle: int, _result: int) -> void:
		state.done = true
	steam.connect("get_auth_session_ticket_response", on_response, CONNECT_ONE_SHOT)
	var waited := 0.0
	while not state.done and waited < TICKET_WAIT_SECONDS:
		await _host.get_tree().process_frame
		waited += _host.get_process_delta_time()
	if steam.is_connected("get_auth_session_ticket_response", on_response):
		steam.disconnect("get_auth_session_ticket_response", on_response)

func _finish(result: Dictionary, used_method: String) -> Dictionary:
	if not result.success:
		if result.code == 404:
			return _fail("FirstLook could not find game slug '%s'" % _config.game_slug)
		return _fail("Login failed: " + result.error)

	var token := ""
	if result.data is Dictionary:
		token = str(result.data.get("jwt_token", ""))
	if token == "":
		return _fail("Login response had no token")

	_http.set_auth_token(token)
	method = used_method
	return { "success": true, "method": used_method, "error": "" }

func _get_or_create_anon_id() -> String:
	var cfg := ConfigFile.new()
	if cfg.load(ANON_ID_PATH) == OK:
		var saved := str(cfg.get_value("firstlook", "anon_id", ""))
		if saved != "":
			return saved
	var new_id := FirstLookHttp.uuid_v4()
	cfg.set_value("firstlook", "anon_id", new_id)
	cfg.save(ANON_ID_PATH)
	return new_id

func _fail(message: String) -> Dictionary:
	return { "success": false, "method": "", "error": message }
