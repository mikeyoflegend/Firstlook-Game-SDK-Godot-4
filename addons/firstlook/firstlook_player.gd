class_name FirstLookPlayer
extends RefCounted

## Emitted when a player claim URL and QR code are available.
## Use this to onboard unlinked players (players who haven't created
## a full FirstLook profile yet).
signal claim_available(claim_url: String, claim_qr_base64: String)

var _http: FirstLookHttp
var _session: FirstLookSession

func _init(http: FirstLookHttp, session: FirstLookSession) -> void:
	_http = http
	_session = session

## Request a claim URL and QR code for the current player.
## Show these in-game so unlinked players can complete their profile.
func get_player_claim() -> void:
	if not _session.is_active:
		push_warning("[FirstLook] get_player_claim called with no active session.")
		return

	var result = await _http.get_request("/client/v1/player/claim")

	if result.success and result.data is Dictionary:
		var url: String = result.data.get("claimUrl", "")
		var qr: String = result.data.get("claimQrCode", "")
		claim_available.emit(url, qr)
	else:
		push_warning("[FirstLook] get_player_claim failed (HTTP %d)" % result.get("code", 0))
