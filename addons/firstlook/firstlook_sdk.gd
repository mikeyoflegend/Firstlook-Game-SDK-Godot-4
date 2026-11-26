## FirstLook SDK for Godot 4
## Community-made by Mikey of Legend. Not officially affiliated with FirstLook.gg.
## API reference: https://api.firstlook.gg/client/docs
##
## Usage:
##   var cfg := FirstLookConfig.new()
##   cfg.game_slug = "your-game-slug"
##   FirstLook.ready_to_use.connect(func(session_id): print("Live! ", session_id))
##   FirstLook.startup_failed.connect(func(err): printerr("Failed: ", err))
##   FirstLook.initialize(cfg)

extends Node

const VERSION := "2.0.0"

## Login and session start worked. Safe to send events from here on.
signal ready_to_use(session_id: String)

## Login or session start failed. Event calls will be skipped until restart.
signal startup_failed(error: String)

## The playtest watermark is enabled for this game. code identifies the
## session if a leaked screenshot or video turns up. Use it for player
## notices; the included WatermarkOverlay draws it for you.
signal watermark_enabled(code: String)

## The session has ended (on quit, or after shutdown()).
signal session_ended

## Same as FirstLook.surveys.survey_available, but safe to connect before
## initialize() runs. The included SurveyScreen listens to this.
signal survey_available(page_response: Dictionary)

## Same as FirstLook.surveys.browser_survey_available.
signal browser_survey_available(page_response: Dictionary)

var config: FirstLookConfig
var http: FirstLookHttp
var auth: FirstLookAuth
var session: FirstLookSession
var events: FirstLookEvents
var surveys: FirstLookSurveys
var player: FirstLookPlayer

## True once login and session start have succeeded.
var is_ready: bool = false

## True after a failed startup. Stays true until the game restarts.
var has_failed: bool = false

## The watermark code for this session, or "" when watermarking is off.
var watermark_code: String = ""

var _starting: bool = false
var _took_over_quit: bool = false
var _quitting: bool = false

## Call once at startup.
func initialize(cfg: FirstLookConfig) -> void:
	if is_ready or _starting:
		push_warning("[FirstLook] initialize() was already called.")
		return
	if cfg == null or cfg.game_slug.strip_edges() == "":
		_fail("game_slug is required. Set it on your FirstLookConfig.")
		return

	config = cfg
	http = FirstLookHttp.new(cfg.api_url, self, cfg.request_timeout)
	http.verbose = cfg.verbose_logging
	auth = FirstLookAuth.new(http, cfg, self)
	session = FirstLookSession.new(http, cfg)
	events = FirstLookEvents.new(http, session, cfg)
	surveys = FirstLookSurveys.new(http, session)
	player = FirstLookPlayer.new(http)
	surveys.survey_available.connect(survey_available.emit)
	surveys.browser_survey_available.connect(browser_survey_available.emit)

	if cfg.end_session_on_quit:
		_setup_quit_handling()

	_starting = true
	await _startup()
	_starting = false

## End the session now. Await it before quitting from your own code:
##   await FirstLook.shutdown()
##   get_tree().quit()
func shutdown() -> void:
	if session == null or not session.is_active:
		return
	if events != null:
		await events.end_all_durations()
	var result := await session.end_session()
	if auth != null:
		auth.release()
	is_ready = false
	if result.success:
		print("[FirstLook] Session ended.")
	else:
		push_warning("[FirstLook] " + result.error)
	session_ended.emit()

func get_session_id() -> String:
	return session.get_session_id() if session != null else ""

func _startup() -> void:
	print("[FirstLook] Signing in (SDK %s)..." % VERSION)
	var auth_result := await auth.authenticate()
	if not auth_result.success:
		_fail(auth_result.error)
		return

	print("[FirstLook] Signed in with %s. Starting session..." % auth_result.method)
	var session_result := await session.start_session()
	if not session_result.success:
		_fail(session_result.error)
		return

	is_ready = true
	print("[FirstLook] Ready. Session: ", session.get_session_id())
	ready_to_use.emit(session.get_session_id())
	_check_watermark()

func _check_watermark() -> void:
	var result := await http.get_request("/client/v1/watermark?session_id=" + session.get_session_id())
	if result.success and result.data is Dictionary and result.data.get("enabled", false):
		watermark_code = str(result.data.get("code", ""))
		if watermark_code != "":
			watermark_enabled.emit(watermark_code)

func _fail(message: String) -> void:
	has_failed = true
	printerr("[FirstLook] Startup failed: ", message)
	startup_failed.emit(message)

# --- Quitting ---
# HTTP requests need a few frames to finish, but Godot normally closes the
# moment the window's X is pressed. If your game has not changed that
# (auto_accept_quit is still on), the SDK holds the close for up to two
# seconds to send session_end, then quits. If your game already handles
# quitting itself, the SDK leaves that alone and you should
# `await FirstLook.shutdown()` before your own get_tree().quit().

const QUIT_WAIT_SECONDS := 2.0

func _setup_quit_handling() -> void:
	var tree := get_tree()
	if tree != null and tree.auto_accept_quit:
		tree.auto_accept_quit = false
		_took_over_quit = true

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		# Godot locks the scene tree while it sends this notification, so
		# the HTTP request has to start on the next frame.
		_on_close_requested.call_deferred()

func _on_close_requested() -> void:
	if _quitting:
		return
	if not _took_over_quit:
		# The game owns quitting. Best effort only.
		if session != null and session.is_active:
			shutdown()
		return
	_quitting = true
	if session != null and session.is_active:
		var timer := get_tree().create_timer(QUIT_WAIT_SECONDS, true, false, true)
		timer.timeout.connect(_finish_quit)
		await shutdown()
	_finish_quit()

func _finish_quit() -> void:
	if is_inside_tree():
		get_tree().quit()
