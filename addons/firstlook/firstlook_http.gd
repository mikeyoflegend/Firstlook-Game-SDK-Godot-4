class_name FirstLookHttp
extends RefCounted

# NOTE: Endpoint paths are modeled on the FirstLook Unity SDK documentation
# and the Unreal plugin manifest. Verify them against the live Swagger UI at
# https://api.firstlook.gg/client/swagger-ui/ before shipping to production.

var _base_url: String
var _auth_token: String = ""

func _init(base_url: String) -> void:
	_base_url = base_url

func set_auth_token(token: String) -> void:
	_auth_token = token

func clear_auth_token() -> void:
	_auth_token = ""

func post(endpoint: String, body: Dictionary) -> Dictionary:
	return await _request(HTTPClient.METHOD_POST, endpoint, body)

func get_request(endpoint: String) -> Dictionary:
	return await _request(HTTPClient.METHOD_GET, endpoint, {})

func _request(method: HTTPClient.Method, endpoint: String, body: Dictionary) -> Dictionary:
	var http = HTTPRequest.new()
	Engine.get_main_loop().root.add_child(http)

	var headers := ["Content-Type: application/json"]
	if _auth_token != "":
		headers.append("Authorization: Bearer " + _auth_token)

	var json_body := JSON.stringify(body) if method == HTTPClient.METHOD_POST else ""
	var err = http.request(_base_url + endpoint, headers, method, json_body)

	if err != OK:
		http.queue_free()
		return { "success": false, "error": "HTTPRequest failed to start (error %d)" % err, "code": 0 }

	var result = await http.request_completed
	http.queue_free()

	return _parse_response(result)

func _parse_response(result: Array) -> Dictionary:
	var response_code: int = result[1]
	var body: PackedByteArray = result[3]

	if body.is_empty():
		return {
			"success": response_code >= 200 and response_code < 300,
			"code": response_code,
			"data": {}
		}

	var text := body.get_string_from_utf8()
	var json := JSON.new()
	var parse_err := json.parse(text)

	if parse_err != OK:
		return { "success": false, "error": "JSON parse failed: " + text, "code": response_code }

	return {
		"success": response_code >= 200 and response_code < 300,
		"code": response_code,
		"data": json.get_data()
	}
