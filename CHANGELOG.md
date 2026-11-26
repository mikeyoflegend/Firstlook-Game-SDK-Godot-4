# Changelog

## 2.0.0 (2026-11-26)

Rebuilt against FirstLook's published Game Client API (`https://api.firstlook.gg/client/docs`) and tested on Godot 4.7.1.

### Fixed
- The plugin now loads in projects without GodotSteam. Before, the auth script failed to compile, which took down the whole `FirstLook` autoload.
- Steam login uses GodotSteam's real method names (`getAuthSessionTicket`, `isSteamRunning`, `getAppID`) and waits for Steam's ticket callback.
- Every endpoint now matches the live API. The 1.x paths (`/client/v1/sessions`, `/client/v1/events/counter`, `/client/v1/surveys/trigger`, and others) do not exist on FirstLook's servers, and request and response fields now use the API's names (`jwt_token`, `session_id`, `counter_name`, and so on).
- The survey screen compiles. It had type errors in Godot 4.7.
- Session end on quit actually sends now. Before, Godot closed before the request left, and the request could not start during the close notification.
- Survey IDs are no longer sent as `42.0` (Godot reads JSON numbers as floats).

### Added
- Anonymous login fallback when Steam is not available.
- Paged surveys with required and conditional questions, "Other" answers, max selections, rating icons, emoji opinion scales, text blocks, images, and the dashboard's thank-you message.
- `survey_screen.tscn`, auto-connected with no code needed.
- Feedback survey (`request_feedback_survey`) and triggered survey list.
- Counter event parameters, with FirstLook's naming rules checked before sending.
- Player info, claim QR code to texture helper, PlayFab identity linking, entitlements.
- Playtest watermark support and `watermark_overlay.tscn`.
- `FirstLook.shutdown()`, `has_failed`, `session_ended` signal, and survey signals on the autoload.
- Config: `use_steam`, `allow_anonymous`, `end_session_on_quit`, `request_timeout`, `verbose_logging`. `build_version` falls back to the project version.

### Changed
- `post_counter_event(name, value)` is now `post_counter_event(name, count, param)`. Old calls keep working.
- Surveys are paged. `submit_response()` is replaced by `submit_page()`.
- Question kinds follow FirstLook's names (`textarea`, `n_p_s`, and so on).
- The survey screen's `survey_submitted` signal still fires, alongside the new `survey_completed`.

## 1.0.0

First release.
