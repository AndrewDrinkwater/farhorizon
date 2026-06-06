class_name Palette
extends RefCounted
## The terminal's colour palette (ADR 0006/0012). Status colours are drawn from
## the colourblind-safe Okabe–Ito set and are NEVER the only channel — every
## state that uses colour also carries a glyph/label (ADR 0012); see TLight and
## the Helm flight-status display.

# Surfaces / text
const BG: Color = Color("0b0e13")
const PANEL: Color = Color("121822")
const PANEL_BORDER: Color = Color("2a3645")
const TEXT: Color = Color("c7d3e0")
const TEXT_DIM: Color = Color("7e8a99")
const ACCENT: Color = Color("56b4e9")

# Status (Okabe–Ito, colourblind-safe) — always paired with a glyph/label.
const STATUS_IDLE: Color = Color("7e8a99")     # grey
const STATUS_INFO: Color = Color("56b4e9")     # sky blue
const STATUS_NOMINAL: Color = Color("009e73")  # bluish green
const STATUS_CAUTION: Color = Color("e69f00")  # orange
const STATUS_ALERT: Color = Color("d55e00")    # vermillion
