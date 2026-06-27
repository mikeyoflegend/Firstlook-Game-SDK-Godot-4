# FirstLook SDK for Godot 4

A community-made Godot 4 plugin that lets you integrate [FirstLook.gg](https://firstlook.gg) into your game. FirstLook is a player relationship platform for indie game studios — it handles playtesting, player analytics, in-game surveys, and more.

> **Not official.** This is a community project, not an official FirstLook product. The official SDKs are for [Unreal](https://docs.firstlook.gg/setup/sdk-setup/unreal) and [Unity](https://docs.firstlook.gg/setup/sdk-setup/unity).

---

## What it does

- Steam authentication via GodotSteam
- Session tracking (start/end, crash-safe graceful shutdown)
- Custom counter events (`match.win`, `loadout.hero-selected`, etc.)
- Custom duration events (`match.round`, `menu.time-spent`, etc.)
- In-game survey delivery and response submission (all 8 question types)
- Player onboarding links and QR codes for unlinked players

---

## Requirements

- **Godot 4.x**
- **GodotSteam** — required for Steam authentication. Get it at [godotsteam.com](https://godotsteam.com).
- A **FirstLook account** with a game set up. Sign up at [firstlook.gg](https://firstlook.gg).

---

## Installation

1. Download or clone this repo.
2. Copy the `addons/firstlook/` folder into your Godot project's `addons/` directory.
3. In the Godot Editor, go to **Project > Project Settings > Plugins** and enable **FirstLook SDK**.
   - This automatically registers `FirstLook` as a global autoload singleton.
4. Make sure GodotSteam is installed and working in your project.

---

## Setup

Create a `FirstLookConfig` resource and call `FirstLook.initialize()` once at startup — typically in your main scene or a game manager node.

```gdscript
extends Node

func _ready() -> void:
    var cfg = FirstLookConfig.new()
    cfg.game_slug = "your-game-slug"      # from your FirstLook dashboard
    cfg.build_version = "0.1.0"           # optional

    FirstLook.ready_to_use.connect(_on_firstlook_ready)
    FirstLook.startup_failed.connect(_on_firstlook_failed)
    FirstLook.initialize(cfg)

func _on_firstlook_ready(session_id: String) -> void:
    print("FirstLook live. Session: ", session_id)

func _on_firstlook_failed(error: String) -> void:
    printerr("FirstLook failed: ", error)
```

Your `game_slug` is in your FirstLook dashboard under game settings.

---

## Events

Event names follow the `category.event-type` convention. FirstLook groups them by prefix in your analytics dashboard.

```gdscript
# Counter event — something happened
await FirstLook.events.post_counter_event("match.win", 1)
await FirstLook.events.post_counter_event("loadout.hero-selected", 1)

# Duration event — measure how long something takes
await FirstLook.events.start_duration_event("match.round")
# ... later ...
await FirstLook.events.end_duration_event("match.round")
```

> Do not use the `firstlook` namespace — it is reserved for built-in SDK events.

---

## Surveys

Set up survey triggers in the FirstLook dashboard, then fire them from your game. If the player qualifies for a survey, `survey_available` is emitted.

```gdscript
# Hook up the survey UI (do this once at setup)
FirstLook.surveys.survey_available.connect($SurveyScreen.show_survey)

# Fire a trigger at the right moment in your game
await FirstLook.surveys.post_trigger_event("match.completed")
```

The included `addons/firstlook/ui/survey_screen.gd` handles all question types automatically. Add a `CanvasLayer` to your scene and attach `survey_screen.gd` to it.

### Supported question types

| Type | Description |
|---|---|
| `single_select` | Pick one option |
| `multi_select` | Pick multiple options |
| `rating` | Star rating (configurable max) |
| `nps` | 0-10 Net Promoter Score |
| `sentiment` | Emoji sentiment scale |
| `yes_no` | Two-button yes or no |
| `text_area` | Freeform text input |
| `matrix` | Grid of single-select rows |

---

## Player onboarding

If a player hasn't created a full FirstLook profile yet (they show as "Unlinked" in your dashboard), you can give them a claim link or QR code to complete onboarding.

```gdscript
FirstLook.player.claim_available.connect(func(url, qr_base64):
    # Show url as a link, or decode qr_base64 as a QR image
    print("Claim URL: ", url)
)

FirstLook.player.get_player_claim()
```

---

## API note

The endpoint paths in this SDK are modeled on the FirstLook Unity SDK documentation and the Unreal plugin manifest. They have not been fully verified against the live API. If you find any discrepancies, please open an issue or PR — see [CONTRIBUTING.md](CONTRIBUTING.md).

Swagger docs: [https://api.firstlook.gg/client/swagger-ui/](https://api.firstlook.gg/client/swagger-ui/)

---

## File structure

```
addons/firstlook/
  plugin.cfg
  firstlook_plugin.gd       # Plugin entry point (registers autoload)
  firstlook_sdk.gd          # Autoload singleton (FirstLook)
  firstlook_config.gd       # Config resource
  firstlook_http.gd         # HTTP helper
  firstlook_auth.gd         # Steam authentication
  firstlook_session.gd      # Session lifecycle
  firstlook_events.gd       # Counter and duration events
  firstlook_surveys.gd      # Survey polling and submission
  firstlook_player.gd       # Player claim and onboarding
  ui/
    survey_screen.gd        # Full survey UI (all question types, dark theme)
```

---

## License

MIT. See [LICENSE](LICENSE).

Made by [Mikey of Legend](https://github.com/mikeyoflegend).
