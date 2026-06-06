# ADR 0001 — Engine, language, renderer, style

**Status:** accepted · **Date:** 2026-06-06

## Context
Greenfield rebuild of Far Horizon. Solo build, developer newer to Godot 4.
Need fast iteration and good 2D + shader support for procedural planets later.

## Decision
- **Godot, latest stable 4.x.** Pin the exact version at project init.
- **GDScript only, strictly typed.** No C#. Types on every var, param, and
  return. `class_name` on shared types.
- **Forward+ renderer.** Full 2D lighting and shader features for the planet
  visuals planned in later phases. Desktop only; no web export.
- **Official Godot style guide:** `snake_case` for methods/vars, `PascalCase`
  for classes, `_` prefix for private members.
- **Target:** 1920×1080 design resolution, 16:9, scaled to other 16:9 sizes.

## Why
GDScript keeps iteration fast and avoids C# build/setup overhead for a solo
project. Strict typing catches errors at parse time — important when the
developer is newer to the engine. Forward+ avoids re-choosing the renderer
later once shaders matter.

## Consequences
- No web build target (acceptable; desktop is the goal).
- Strict typing adds a little friction but pays back in fewer runtime
  surprises and better editor autocomplete.
