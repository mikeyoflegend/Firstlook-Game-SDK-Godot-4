class_name FirstLookConfig
extends Resource

## Your game slug from the FirstLook dashboard. Required.
@export var game_slug: String = ""

## Optional build label sent with session, counter, and duration events
## (for example "0.1.0-alpha"). Leave empty to use the project's
## application/config/version setting. Keep values consistent so the
## dashboard can filter on them.
@export var build_version: String = ""

## The base API URL. You should not need to change this.
@export var api_url: String = "https://api.firstlook.gg"

## Your game's FirstLook domain, used only for browser-delivered surveys.
## Format: https://<game-slug>.firstlook.gg
@export var client_url: String = ""

## Try Steam login first (needs GodotSteam, initialized by your game).
@export var use_steam: bool = true

## If Steam is unavailable, sign in anonymously instead of failing.
## The anonymous ID is saved in user:// so the same machine keeps the
## same player across launches.
@export var allow_anonymous: bool = true

## End the FirstLook session automatically when the game window closes.
## See README "Quitting" for how this interacts with your own quit logic.
@export var end_session_on_quit: bool = true

## Seconds before a request to FirstLook gives up.
@export var request_timeout: float = 10.0

## Print extra debug info to the output panel.
@export var verbose_logging: bool = false
