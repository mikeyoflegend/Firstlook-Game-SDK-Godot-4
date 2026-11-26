# FirstLook SDK for Godot 4

A community-made Godot 4 plugin that connects your game to [FirstLook.gg](https://firstlook.gg), the player relationship platform for playtesting, player analytics, and in-game surveys.

> **Not official.** This is a community project, not an official FirstLook product. The official SDKs are for [Unreal](https://docs.firstlook.gg/developers/sdk/unreal/) and [Unity](https://docs.firstlook.gg/developers/sdk/unity/). This plugin talks to the same public [Game Client API](https://api.firstlook.gg/client/docs).

---

## What it does

- Steam login through GodotSteam, with an anonymous fallback so it works without Steam too
- Session tracking that ends cleanly when the player closes the game
- Counter events (`match.win`), including parameter variants (`level.started#forest_3`)
- Duration events (`match.round`)
- Paged in-game surveys with a ready-made dark UI (text, single and multi choice with "Other", rating, NPS, opinion scale with emojis, yes/no, text blocks, images), required questions, and conditional questions
- Player info, claim links and QR codes for unlinked players, PlayFab identity linking
- Entitlements
- The FirstLook playtest watermark

---

## Requirements

- **Godot 4.7+** (tested on 4.7.1)
- **GodotSteam** (optional). Needed only for Steam login. Get it at [godotsteam.com](https://godotsteam.com). Your game needs to initialize Steam itself, as usual.
- A **FirstLook account** with a game set up. Your game slug is in the FirstLook dashboard.

---

## Installation

1. Download or clone this repo.
2. Copy the `addons/firstlook/` folder into your project's `addons/` folder.
3. In Godot, open **Project > Project Settings > Plugins** and enable **FirstLook SDK**. This adds a global `FirstLook` autoload.

---

## Setup

Call `FirstLook.initialize()` once when your game starts, for example in your main scene.

```gdscript
extends Node

func _ready() -> void:
    var cfg := FirstLookConfig.new()
    cfg.game_slug = "your-game-slug"      # from your FirstLook dashboard

    FirstLook.ready_to_use.connect(_on_firstlook_ready)
    FirstLook.startup_failed.connect(_on_firstlook_failed)
    FirstLook.initialize(cfg)

func _on_firstlook_ready(session_id: String) -> void:
    print("FirstLook is live. Session: ", session_id)

func _on_firstlook_failed(error: String) -> void:
    printerr("FirstLook could not start: ", error)
```

Calls made before `ready_to_use` (or after a failed startup) are skipped with a warning, so they never crash your game.

### Config options

| Option | Default | What it does |
|---|---|---|
| `game_slug` | | Required. Your game's slug. |
| `build_version` | project version | Sent with sessions and events. Empty uses **Application > Config > Version**. |
| `use_steam` | `true` | Try Steam login first. |
| `allow_anonymous` | `true` | If Steam is not available, sign in anonymously. |
| `end_session_on_quit` | `true` | End the session when the window closes. See [Quitting](#quitting). |
| `request_timeout` | `10.0` | Seconds before a request gives up. |
| `verbose_logging` | `false` | Print every request and response. Handy while setting up. |
| `api_url` | `https://api.firstlook.gg` | You should not need to change this. |
| `client_url` | | Your `https://<game-slug>.firstlook.gg` domain, for browser surveys. |

### Steam login

If GodotSteam is installed and Steam is running, the SDK uses it automatically. Steam only confirms a login ticket through a callback, so make sure Steam callbacks are running (`Steam.run_callbacks()` every frame, or GodotSteam's embedded callbacks setting). The SDK waits up to 3 seconds for that callback, then continues either way.

---

## Events

Name events `<category>.<event-type>`. FirstLook groups them by category. The `firstlook` namespace is reserved.

```gdscript
# Something happened
FirstLook.events.post_counter_event("match.win")
FirstLook.events.post_counter_event("loadout.hero-selected", 1)

# With a parameter. Stored as "level.started#forest_3" and also counted
# in the "level.started" total. Parameters are lowercased, max 64
# characters, and cannot contain "#". Keep the set of values small.
FirstLook.events.post_counter_event("level.started", 1, "forest_3")

# How long something takes
FirstLook.events.start_duration_event("match.round")
# ... later ...
FirstLook.events.end_duration_event("match.round")
```

Durations that are still running when the session ends are closed automatically.

---

## Surveys

1. Build your survey in the FirstLook dashboard, turn on game client distribution, and set its trigger (for example `match.completed`).
2. Drag `addons/firstlook/ui/survey_screen.tscn` into your main scene. It shows surveys by itself.
3. Fire the trigger at the right moment:

```gdscript
FirstLook.surveys.post_trigger_event("match.completed")
```

That's it. The screen handles paging, required questions, conditional questions, the thank-you message, and makes the mouse cursor visible while it is open.

You can also ask for your game's feedback survey at any time:

```gdscript
FirstLook.surveys.request_feedback_survey()
```

### Survey screen signals

```gdscript
$FirstLookSurveyScreen.survey_completed.connect(func(): print("Thanks!"))
$FirstLookSurveyScreen.survey_dismissed.connect(func(): print("Closed early"))
```

### Question types

| FirstLook type | Shown in-game | Notes |
|---|---|---|
| Text | Yes | Single or multiple lines |
| Dropdown (single choice) | Yes | Shown as a list of buttons, "Other" supported |
| Multiple choice | Yes | Max selections and "Other" supported |
| Rating | Yes | Star, heart, smile, or thumbs-up icon |
| NPS | Yes | 0 to 10 |
| Opinion scale | Yes | Numbers or emojis, optional end labels |
| Yes/No | Yes | |
| Text block | Yes | |
| Image | Yes | PNG, JPG, or WebP |
| Matrix, Image choice, Video | Browser only | FirstLook supports these on the web only |

Surveys that need the browser arrive on a separate signal. FirstLook's public docs do not yet say which URL the overlay should open, so this SDK hands you the survey and leaves opening it to you:

```gdscript
FirstLook.browser_survey_available.connect(func(page_response):
    print("Browser survey: ", page_response.survey.uuid)
)
```

### Building your own survey UI

Connect to `FirstLook.survey_available`, draw `page_response.page.questions`, then send answers with the question `uuid` as the key:

```gdscript
var next := await FirstLook.surveys.submit_page(page_response, { question_uuid: answer })
if next.get("completed", false):
    print("Done")
```

---

## Player

```gdscript
var me := await FirstLook.player.get_current_player()
if FirstLook.player.is_unlinked():
    # Needs the "From Game" claim flow set up in your dashboard
    var claim := await FirstLook.player.get_player_claim()
    $ClaimLink.text = claim.claim_url
    $QRCode.texture = FirstLookPlayer.qr_to_texture(claim.claim_qr_code)

# Link a PlayFab ID (the only provider FirstLook supports). Safe every launch.
FirstLook.player.link_identity("playfab", playfab_id)
```

### Entitlements

```gdscript
for e in await FirstLook.player.get_entitlements():
    if e.sku == "skin.gold":
        give_gold_skin()
        await FirstLook.player.redeem_entitlement(e.id)
```

Entitlements are not an ownership check. Save what the player owns in your own data, and match on `sku`, not `name`.

---

## Playtest watermark

If FirstLook turns on **Playtest Watermark** for your game, drag `addons/firstlook/ui/watermark_overlay.tscn` into your main scene. It stays hidden until FirstLook says the watermark is on, then draws the session code faintly across the screen. Color, opacity, density, angle, and drift are adjustable in the Inspector. The code is also available as `FirstLook.watermark_code` and the `watermark_enabled` signal.

---

## Quitting

FirstLook leaves sessions that never end out of its averages, so ending cleanly matters.

- **If your game just closes when the window X is pressed** (Godot's default), you don't need to do anything. The SDK holds the close for up to 2 seconds, sends the session end, then quits.
- **If your game handles quitting itself** (a "Are you sure?" dialog, a Quit button), end the session first:

```gdscript
await FirstLook.shutdown()
get_tree().quit()
```

A crash cannot send a session end. That is expected, and FirstLook handles it.

---

## Not yet confirmed against a live game

Everything here follows FirstLook's published API spec and was tested against a mock server built from it. A few details the spec does not spell out are educated guesses. If something looks wrong in your dashboard after a real playtest, these are the places to look:

- **Login header.** The token is sent as `Authorization: Bearer <token>`. If every call after login returns 401, this is why (`firstlook_http.gd`).
- **Answer format.** FirstLook stores answers as text. Multiple choice answers are sent as a JSON list (`["art","music"]`), yes/no as `yes`/`no`. All conversion lives in `FirstLookSurveys.encode_answer()`.
- **NPS range.** Sent as 0 to 10 (the standard). FirstLook's docs mention 1 to 10.

---

## File structure

```
addons/firstlook/
  plugin.cfg
  firstlook_plugin.gd        # Registers the FirstLook autoload
  firstlook_sdk.gd           # The FirstLook autoload
  firstlook_config.gd        # Settings
  firstlook_http.gd          # Talks to the API
  firstlook_auth.gd          # Steam and anonymous login
  firstlook_session.gd       # Session start and end
  firstlook_events.gd        # Counter and duration events
  firstlook_surveys.gd       # Survey triggers and page submission
  firstlook_player.gd        # Player, claims, identity, entitlements
  ui/
    survey_screen.tscn/.gd   # Ready-made survey UI
    watermark_overlay.tscn/.gd
```

---

## License

MIT. See [LICENSE](LICENSE).

Made by [Mikey of Legend](https://github.com/mikeyoflegend).
