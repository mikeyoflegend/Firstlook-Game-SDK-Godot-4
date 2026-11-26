class_name FirstLookHttp
extends RefCounted

## Thin JSON-over-HTTP helper for the FirstLook Game Client API.
## Reference: https://api.firstlook.gg/client/docs
##
## Every call returns a Dictionary:
##   { "success": bool, "code": int, "data": Variant, "error": String }

var _base_url: String
var _host: Node
var _timeout: float
var _auth_token: String = ""
var verbose: bool = false

func _init(base_url: String, host: Node, timeout: float = 10.0) -> void:
	_base_url = base_url.rstrip("/")
	_host = host
	_timeout = timeout

func set_auth_token(token: String) -> void:
	_auth_token = token

func clear_auth_token() -> void:
	_auth_token = ""

func has_auth_token() -> bool:
	return _auth_token != ""

func post(endpoint: String, body: Variant = null) -> Dictionary:
	return await _request(HTTPClient.METHOD_POST, endpoint, body)

func get_request(endpoint: String) -> Dictionary:
	return await _request(HTTPClient.METHOD_GET, endpoint, null)

func _request(method: HTTPClient.Method, endpoint: String, body: Variant) -> Dictionary:
	if _host == null or not is_instance_valid(_host) or not _host.is_inside_tree():
		return _fail(0, "FirstLook SDK node is not in the scene tree.")

	var http := HTTPRequest.new()
	http.timeout = _timeout
	_host.add_child(http)

	var headers := PackedStringArray(["Content-Type: application/json", "Accept: application/json"])
	if _auth_token != "":
		headers.append("Authorization: Bearer " + _auth_token)

	var payload := ""
	if method == HTTPClient.METHOD_POST:
		payload = JSON.stringify(body) if body != null else "{}"

	var url := _base_url + endpoint
	if verbose:
		print("[FirstLook] -> %s %s %s" % ["POST" if method == HTTPClient.METHOD_POST else "GET", url, payload])

	var err := http.request(url, headers, method, payload)
	if err != OK:
		http.queue_free()
		return _fail(0, "HTTPRequest failed to start (error %d)." % err)

	var result: Array = await http.request_completed
	http.queue_free()
	return _parse_response(result)

func _parse_response(result: Array) -> Dictionary:
	var request_result: int = result[0]
	var code: int = result[1]
	var body: PackedByteArray = result[3]

	if request_result != HTTPRequest.RESULT_SUCCESS:
		var reason := "network error %d" % request_result
		if request_result == HTTPRequest.RESULT_TIMEOUT:
			reason = "request timed out"
		elif request_result == HTTPRequest.RESULT_CANT_CONNECT or request_result == HTTPRequest.RESULT_CANT_RESOLVE:
			reason = "could not reach the FirstLook API"
		return _fail(0, reason)

	var ok := code >= 200 and code < 300
	var data: Variant = {}
	var text := body.get_string_from_utf8()

	if text.strip_edges() != "":
		var json := JSON.new()
		if json.parse(text) == OK:
			data = json.get_data()
		elif ok:
			return _fail(code, "Could not read the server response: " + text.left(200))
		else:
			data = { "error": text.left(200) }

	if verbose:
		print("[FirstLook] <- %d %s" % [code, text.left(500)])

	if ok:
		return { "success": true, "code": code, "data": data, "error": "" }

	var message := "HTTP %d" % code
	if data is Dictionary and data.has("error"):
		message = "%s (HTTP %d)" % [str(data["error"]), code]
	return { "success": false, "code": code, "data": data, "error": message }

func _fail(code: int, message: String) -> Dictionary:
	return { "success": false, "code": code, "data": {}, "error": message }

## FirstLook IDs are integers, but Godot's JSON parser reads every number
## as a float (42 becomes 42.0). Use this when putting an ID in a URL.
static func id_string(id: Variant) -> String:
	if id is float and is_equal_approx(id, round(id)):
		return str(int(id))
	return str(id)

## ISO 8601 UTC timestamp, the format every analytics endpoint expects.
static func timestamp() -> String:
	return Time.get_datetime_string_from_system(true) + "Z"

## Random version 4 UUID. FirstLook session IDs are created by the client.
static func uuid_v4() -> String:
	var b := Crypto.new().generate_random_bytes(16)
	b[6] = (b[6] & 0x0f) | 0x40
	b[8] = (b[8] & 0x3f) | 0x80
	var h := b.hex_encode()
	return "%s-%s-%s-%s-%s" % [h.substr(0, 8), h.substr(8, 4), h.substr(12, 4), h.substr(16, 4), h.substr(20, 12)]
