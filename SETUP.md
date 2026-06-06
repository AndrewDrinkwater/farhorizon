# Setup — first time

## 1. Open the project
Open Godot **4.6** and import this folder (it contains `project.godot`). On
first open Godot will:
- build its `.godot/` cache (gitignored),
- import `icon.svg` and `localization/strings.csv`,
- detect the **GUT** plugin in `addons/gut`.

If GUT isn't already enabled: **Project → Project Settings → Plugins → enable
"Gut"**. (It's pre-enabled in `project.godot`, but the toggle confirms it.)

## 2. Localisation (one-time, needs the editor)
The string table is `localization/strings.csv`. Godot imports CSVs as
translations automatically. After first import, register the locale:
**Project → Project Settings → Localization → Translations → Add** →
`localization/strings.en.translation`.

After that, any UI text uses `tr("KEY")` (e.g. `tr("HELM_LAY_IN_COURSE")`).
English is the only locale for now; adding a language = adding a column to the
CSV (ADR 0010).

## 3. Run
Press **Play** (F5). The scaffold scene prints a boot line and shows a label —
this just proves the six autoloads load and the project boots.

## 4. Tests
- **In editor:** open the **GUT** panel (bottom dock), point it at `res://tests/`
  (config is in `.gutconfig.json`), Run All.
- **Headless** (CI-style), from the project root:
  ```
  godot --headless -s addons/gut/gut_cmdln.gd -gconfig=.gutconfig.json
  ```

## 5. Remote
The git remote (`origin`) is already configured. Push as normal:
```
git push -u origin main
```

---

If a build-order step needs additional setup, it's noted in
`docs/ALPHA-0.1-SPEC.md`.
