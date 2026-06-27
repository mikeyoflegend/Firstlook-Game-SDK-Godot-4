class_name FirstLookAuth
extends RefCounted

# Requires GodotSteam: https://godotsteam.com
# Steam.get_auth_session_ticket() returns a PackedByteArray in GodotSteam 4.x.

var _http: FirstLookHttp
var _config: FirstLookConfig

func _init(http: FirstLookHttp, config: FirstLookConfig) -> void:
	_http = http
	_config = config

## Authenticate using a Steam session ticket.
## Returns { success, token, player_id, error }
func authenticate_steam() -> Dictionary:
	if not _steam_available():
		return { "success": false, "error": "GodotSteam is not available. Install it from https://godotsteam.com" }

	if not Steam.is_steam_running():
		return { "success": false, "error": "Steam is not running." }

	# GodotSteam 4.x returns a PackedByteArray from get_auth_session_ticket()
	var ticket_data = Steam.get_auth_session_ticket()
	if ticket_data == null or (ticket_data is PackedByteArray and ticket_data.is_empty()):
		return { "success": false, "error": "Could not get Steam session ticket. Is the Steam client running and logged in?" }

	var hex_ticket: String
	if ticket_data is PackedByteArray:
		hex_ticket = ticket_data.hex_encode()
	else:
		# Older GodotSteam versions may return a Dictionary
		hex_ticket = ticket_data.get("buffer", PackedByteArray()).hex_encode()

	var app_id: int = Steam.get_app_id()

	var result = await _http.post("/client/v1/auth/steam", {
		"steamSessionTicket": hex_ticket,
		"steamAppId": str(app_id),
		"gameSlug": _config.game_slug
	})

	if not result.success:
		var msg: String = ""
		if result.get("data") is Dictionary:
			msg = result["data"].get("message", "")
		return { "success": false, "error": msg if msg != "" else "Steam auth failed (HTTP %d)" % result.get("code", 0) }

	var token: String = result.data.get("token", "")
	_http.set_auth_token(token)

	return {
		"success": true,
		"token": token,
		"player_id": result.data.get("playerId", "")
	}

func _steam_available() -> bool:
	return Engine.has_singleton("Steam")
