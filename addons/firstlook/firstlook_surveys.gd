class_name FirstLookSurveys
extends RefCounted

## Emitted when a survey is available after a trigger event.
## Connect this to show your survey UI.
signal survey_available(survey_data: Dictionary)

var _http: FirstLookHttp
var _session: FirstLookSession
var _active_survey: Dictionary = {}

func _init(http: FirstLookHttp, session: FirstLookSession) -> void:
	_http = http
	_session = session

## Fire a named trigger event. If a survey is configured for this trigger
## and the player qualifies, survey_available will be emitted.
## trigger_name matches what you set up in the FirstLook dashboard.
func post_trigger_event(trigger_name: String) -> void:
	if not _session.is_active:
		push_warning("[FirstLook] post_trigger_event called with no active session.")
		return

	var result = await _http.post("/client/v1/surveys/trigger", {
		"sessionId": _session.get_session_id(),
		"eventName": trigger_name
	})

	if result.success and result.data is Dictionary and result.data.has("survey"):
		_active_survey = result.data["survey"]
		survey_available.emit(_active_survey)

## Submit a player's responses to the active survey.
## responses is an Array of { questionId, value } Dictionaries.
func submit_response(survey_id: String, responses: Array) -> Dictionary:
	if not _session.is_active:
		return { "success": false, "error": "No active session." }

	var result = await _http.post("/client/v1/surveys/" + survey_id + "/responses", {
		"sessionId": _session.get_session_id(),
		"responses": responses
	})

	if result.success:
		_active_survey = {}

	return result

func get_active_survey() -> Dictionary:
	return _active_survey
