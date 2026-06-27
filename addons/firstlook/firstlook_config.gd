class_name FirstLookConfig
extends Resource

## The base API URL. You should not need to change this.
@export var api_url: String = "https://api.firstlook.gg"

## Your game's FirstLook domain. Only required for browser-delivered surveys.
## Format: https://<game-slug>.firstlook.gg
@export var client_url: String = ""

## Your game slug from the FirstLook dashboard. Required.
@export var game_slug: String = ""

## Optional build label attached to analytics events (e.g. "0.1.0-alpha").
@export var build_version: String = ""
