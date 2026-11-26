class_name FirstLookPlayer
extends RefCounted

## The signed-in player: profile, claim links for unlinked players,
## identity linking, and entitlements.
##
## Endpoints:
##   POST /client/v0/me
##   POST /client/v1/player_claims/create
##   POST /client/v1/me/identities
##   GET  /client/v0/entitlements
##   POST /client/v0/entitlements/{id}/redeem

## Emitted when get_current_player() succeeds.
signal current_player_available(player: Dictionary)

## Emitted when a claim URL and QR code are ready. claim_qr_base64 is a
## Base64 image you can turn into a texture with qr_to_texture().
signal claim_available(claim_url: String, claim_qr_base64: String)

var _http: FirstLookHttp

## The last player record from get_current_player(), or {}.
var current: Dictionary = {}

func _init(http: FirstLookHttp) -> void:
	_http = http

## Fetch the player record. Returns it, or {} on failure.
## Shape: { player: { id, state, first_name, last_name }, steam, discord, role, invites }
func get_current_player() -> Dictionary:
	if not _ready_check("get_current_player"):
		return {}
	var result := await _http.post("/client/v0/me")
	if not result.success or not (result.data is Dictionary):
		push_warning("[FirstLook] get_current_player failed: " + result.error)
		return {}
	current = result.data
	current_player_available.emit(current)
	return current

## True if the player has not finished a FirstLook profile yet.
## Call get_current_player() first.
func is_unlinked() -> bool:
	return get_state() == "unlinked"

func is_linked() -> bool:
	var state := get_state()
	return state != "" and state != "unlinked"

## The player state as a lowercase string, for example "onboarded".
func get_state() -> String:
	return str(current.get("player", {}).get("state", "")).to_lower()

## Ask for a claim link so an unlinked player can finish their profile.
## Needs the "From Game" claim flow set up in your FirstLook dashboard.
## Returns { claim_url, claim_qr_code } or {}.
func get_player_claim() -> Dictionary:
	if not _ready_check("get_player_claim"):
		return {}
	var result := await _http.post("/client/v1/player_claims/create")
	if not result.success or not (result.data is Dictionary):
		push_warning("[FirstLook] get_player_claim failed: " + result.error)
		return {}
	var url := str(result.data.get("claim_url", ""))
	var qr := str(result.data.get("claim_qr_code", ""))
	claim_available.emit(url, qr)
	return result.data

## Turn the Base64 QR code into a texture for a TextureRect.
## Accepts plain Base64 or a "data:image/png;base64,..." string.
static func qr_to_texture(claim_qr_base64: String) -> ImageTexture:
	var b64 := claim_qr_base64
	var comma := b64.find(",")
	if b64.begins_with("data:") and comma != -1:
		b64 = b64.substr(comma + 1)
	var bytes := Marshalls.base64_to_raw(b64)
	if bytes.is_empty():
		return null
	var img := Image.new()
	if img.load_png_from_buffer(bytes) != OK and img.load_jpg_from_buffer(bytes) != OK and img.load_svg_from_buffer(bytes) != OK:
		return null
	return ImageTexture.create_from_image(img)

## Link an external account ID. FirstLook only supports "playfab" today.
## Safe to call on every startup. Returns { success, code, error }.
##   403: linking not enabled for your game, 409: ID belongs to another
##   player, 422: ID empty or over 64 characters.
func link_identity(provider: String, external_id: String) -> Dictionary:
	if not _ready_check("link_identity"):
		return { "success": false, "code": 0, "error": "FirstLook is not ready." }
	var result := await _http.post("/client/v1/me/identities", { "provider": provider, "id": external_id })
	if not result.success:
		push_warning("[FirstLook] link_identity failed: " + result.error)
	return result

## Unredeemed FirstLook entitlements for this player. This is not an
## ownership check: track what the player owns in your own save data.
## Match items on "sku", not "name". Returns an Array of Dictionaries.
func get_entitlements() -> Array:
	if not _ready_check("get_entitlements"):
		return []
	var result := await _http.get_request("/client/v0/entitlements")
	if not result.success:
		push_warning("[FirstLook] get_entitlements failed: " + result.error)
		return []
	var data: Variant = result.data
	if data is Array:
		return data
	if data is Dictionary:
		for key in ["entitlements", "items", "data"]:
			if data.get(key) is Array:
				return data[key]
	return []

## Redeem once. A repeat redeem returns HTTP 400 "Entitlement already
## redeemed", which you can treat as done.
func redeem_entitlement(entitlement_id: Variant) -> Dictionary:
	if not _ready_check("redeem_entitlement"):
		return { "success": false, "code": 0, "error": "FirstLook is not ready." }
	return await _http.post("/client/v0/entitlements/%s/redeem" % FirstLookHttp.id_string(entitlement_id))

func _ready_check(caller: String) -> bool:
	if _http.has_auth_token():
		return true
	push_warning("[FirstLook] %s skipped: FirstLook is not ready yet." % caller)
	return false
