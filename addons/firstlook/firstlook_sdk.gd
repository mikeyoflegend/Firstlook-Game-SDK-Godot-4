## FirstLook SDK for Godot 4
## Community-made by Mikey of Legend. Not officially affiliated with FirstLook.gg.
##
## Usage:
##   var cfg = FirstLookConfig.new()
##   cfg.game_slug = "your-game-slug"
##   cfg.build_version = "1.0.0"  # optional
##   FirstLook.initialize(cfg)
##
##   FirstLook.ready_to_use.connect(func(session_id): print("Live! ", session_id))
##   FirstLook.startup_failed.connect(func(err): printerr("Failed: ", err))

extends Node

## Emitted when auth and session startup succeed. session_id is the active session.
signal ready_to_use(session_id: String)

## Emitted if auth or session startup fails.
signal startup_failed(error: String)

var config: FirstLookConfig
var http: FirstLookHttp
var auth: FirstLookAuth
var session: FirstLookSession
var events: FirstLookEvents
var surveys: FirstLookSurveys
var player: FirstLookPlayer

## True once auth + session startup has completed successfully.
var is_ready: bool = false

## Initialize the SDK. Call this once at startup before anything else.
func initialize(cfg: FirstLookConfig) -> void:
	if is_ready:
		push_warning("[FirstLook] initialize() called but SDK is already ready.")
		return

	if cfg.game_slug == "":
		push_error("[FirstLook] game_slug is required. Set it on your FirstLookConfig.")
		return

	config = cfg
	http = FirstLookHttp.new(config.api_url)
	auth = FirstLookAuth.new(http, config)
	session = FirstLookSession.new(http, config)
	events = FirstLookEvents.new(http, session)
	surveys = FirstLookSurveys.new(http, session)
	player = FirstLookPlayer.new(http, session)

	_startup()

func _startup() -> void:
	print("[FirstLook] Authenticating via Steam...")
	var auth_result: Dictionary = await auth.authenticate_steam()

	if not auth_result.success:
		var err: String = auth_result.get("error", "Unknown auth error.")
		printerr("[FirstLook] Auth failed: ", err)
		startup_failed.emit(err)
		return

	print("[FirstLook] Authenticated. Starting session...")
	var session_result: Dictionary = await session.start_session()

	if not session_result.success:
		var err: String = session_result.get("error", "Unknown session error.")
		printerr("[FirstLook] Session start failed: ", err)
		startup_failed.emit(err)
		return

	is_ready = true
	print("[FirstLook] Ready. Session: ", session.get_session_id())
	ready_to_use.emit(session.get_session_id())

func _notification(what: int) -> void:
	# Best-effort graceful session end on quit or crash, mirrors Unity SDK behavior.
	if what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_CRASH:
		if session != null and session.is_active:
			session.end_session()
