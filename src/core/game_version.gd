class_name GameVersion
extends RefCounted
## Single source of truth for version numbers (CONVENTIONS.md, ADR 0008).
##
## GAME_VERSION is written into every save and shown in the UI.
## SAVE_SCHEMA_VERSION advances independently when the save format changes.

const GAME_VERSION: String = "0.1.0"
const SAVE_SCHEMA_VERSION: int = 1
