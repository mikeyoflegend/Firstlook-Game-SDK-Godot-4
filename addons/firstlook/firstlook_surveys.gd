class_name FirstLookSurveys
extends RefCounted

## In-game surveys. Surveys are paged: FirstLook sends one page at a time,
## you submit that page's answers, and the reply is the next page (or
## completed = true when the survey is done).
##
## Endpoints:
##   POST /client/v1/surveys/events               fire a trigger
##   GET  /client/v1/surveys/feedback             the game's feedback survey
##   GET  /client/v1/surveys/triggered            surveys already triggered
##   POST /client/v1/surveys/{survey_id}/pages    submit a page, get the next
##
## A "page response" Dictionary looks like:
##   {
##     "survey": { "id", "uuid", "name", "description", "settings", ... },
##     "page": { "id", "title", "description", "questions": [...] } or null,
##     "page_index": int or null,
##     "response_id": int or null,
##     "completed": bool,
##     "gated": bool,
##   }

## A survey for the built-in native UI is ready to show.
signal survey_available(page_response: Dictionary)

## A survey that must be shown in a browser (it uses question types the
## native UI cannot draw, or the dashboard is set to browser delivery).
signal browser_survey_available(page_response: Dictionary)

## Question kinds the native UI can draw. Others need the browser.
const NATIVE_KINDS := ["block", "textarea", "single_select", "multi_select",
	"rating", "n_p_s", "sentiment", "yes_no", "image"]

var _http: FirstLookHttp
var _session: FirstLookSession
var _trigger_counts: Dictionary = {}
var _active: Dictionary = {}

func _init(http: FirstLookHttp, session: FirstLookSession) -> void:
	_http = http
	_session = session

## Fire a trigger you set up in the FirstLook dashboard, for example
## "match.completed". If a survey matches, survey_available (or
## browser_survey_available) is emitted. Also returns the page response,
## or an empty Dictionary if no survey matched.
func post_trigger_event(trigger_name: String) -> Dictionary:
	if not _http.has_auth_token():
		push_warning("[FirstLook] post_trigger_event skipped: FirstLook is not ready yet.")
		return {}

	# FirstLook can target "the player's 3rd time doing X", so we send how
	# many times each trigger has fired this session.
	_trigger_counts[trigger_name] = int(_trigger_counts.get(trigger_name, 0)) + 1
	var event_data: Array = []
	for key in _trigger_counts:
		event_data.append({ "name": key, "value": _trigger_counts[key] })

	var result := await _http.post("/client/v1/surveys/events", {
		"event_data": event_data,
		"current_event": trigger_name,
	})
	if not result.success:
		push_warning("[FirstLook] Survey trigger failed: " + result.error)
		return {}
	return _deliver(result.data)

## Ask for the game's feedback survey (set in the dashboard). Emits the
## same signals as post_trigger_event.
func request_feedback_survey() -> Dictionary:
	if not _http.has_auth_token():
		push_warning("[FirstLook] request_feedback_survey skipped: FirstLook is not ready yet.")
		return {}
	var result := await _http.get_request("/client/v1/surveys/feedback")
	if not result.success:
		push_warning("[FirstLook] Feedback survey request failed: " + result.error)
		return {}
	return _deliver(result.data)

## List surveys that were already triggered for this player.
## Returns an Array of page responses. Does not emit signals.
func get_triggered_surveys(limit: int = 10) -> Array:
	if not _http.has_auth_token():
		return []
	var result := await _http.get_request("/client/v1/surveys/triggered?limit=%d" % limit)
	if result.success and result.data is Array:
		return result.data
	return []

## Submit the answers for the current page.
##   answers: { question_uuid: value }  (values are converted with encode_answer)
## Returns the next page response. Check ["completed"] to see if it is done.
## Returns { "error": "..." } on failure.
func submit_page(page_response: Dictionary, answers: Dictionary) -> Dictionary:
	var survey: Dictionary = page_response.get("survey", {})
	var page: Variant = page_response.get("page")
	if survey.is_empty() or not (page is Dictionary):
		return { "error": "That survey has no page to submit." }

	var data := {}
	for question_uuid in answers:
		var encoded := encode_answer(answers[question_uuid])
		if encoded != "":
			data[str(question_uuid)] = encoded

	var body := { "page_id": str(page.get("id", "")), "data": data }
	if page_response.get("response_id") != null:
		body["response_id"] = int(page_response["response_id"])

	var result := await _http.post("/client/v1/surveys/%s/pages" % FirstLookHttp.id_string(survey.get("id", "")), body)
	if not result.success:
		return { "error": result.error }

	var next: Dictionary = result.data if result.data is Dictionary else {}
	_active = {} if next.get("completed", false) else next
	return next

## The page response currently in progress, or {}.
func get_active_survey() -> Dictionary:
	return _active

## FirstLook stores every answer as a string. This is how values are
## converted. If a question type comes out wrong in your dashboard, this
## is the one place to adjust.
static func encode_answer(value: Variant) -> String:
	match typeof(value):
		TYPE_NIL:
			return ""
		TYPE_STRING, TYPE_STRING_NAME:
			return str(value)
		TYPE_BOOL:
			return "yes" if value else "no"
		TYPE_INT:
			return str(value)
		TYPE_FLOAT:
			return str(int(value)) if is_equal_approx(value, round(value)) else str(value)
		TYPE_ARRAY, TYPE_PACKED_STRING_ARRAY, TYPE_DICTIONARY:
			return JSON.stringify(value)
	return str(value)

## Where a survey should be shown: "native" or "browser".
static func get_delivery(page_response: Dictionary) -> String:
	var survey: Dictionary = page_response.get("survey", {})
	var settings: Variant = survey.get("settings", {})
	if settings is Dictionary and settings.has("SurveyV2"):
		var v2: Dictionary = settings["SurveyV2"]
		var mode := str(v2.get("distribution", {}).get("platforms", {}).get("client", {}).get("distribution", "native"))
		if mode == "browser":
			return "browser"
		for p in v2.get("pages", []):
			for q in p.get("questions", []):
				if not NATIVE_KINDS.has(str(q.get("kind", ""))):
					return "browser"
	var page: Variant = page_response.get("page")
	if page is Dictionary:
		for q in page.get("questions", []):
			if not NATIVE_KINDS.has(str(q.get("kind", ""))):
				return "browser"
	return "native"

## Total pages in the survey, or 0 if unknown.
static func get_page_count(page_response: Dictionary) -> int:
	var settings: Variant = page_response.get("survey", {}).get("settings", {})
	if settings is Dictionary and settings.has("SurveyV2"):
		return settings["SurveyV2"].get("pages", []).size()
	return 0

## The thank-you message set in the dashboard, or {}.
static func get_completion_message(page_response: Dictionary) -> Dictionary:
	var settings: Variant = page_response.get("survey", {}).get("settings", {})
	if settings is Dictionary and settings.has("SurveyV2"):
		var msg: Variant = settings["SurveyV2"].get("completion_message")
		if msg is Dictionary:
			return msg
	return {}

func _deliver(data: Variant) -> Dictionary:
	if not (data is Dictionary) or data.is_empty():
		return {}
	if data.get("completed", false) or data.get("page") == null:
		return {}
	_active = data
	if get_delivery(data) == "browser":
		browser_survey_available.emit(data)
	else:
		survey_available.emit(data)
	return data
