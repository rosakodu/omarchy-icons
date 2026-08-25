# AGENTS.md — Omarchy Icons Plugin Reference

This document is the primary reference for AI coding agents working on the **`omarchy-icons`** plugin.

---

## 1. Project Overview

* **Name / Plugin ID:** `icons`
* **Type:** Omarchy `bar-widget` plugin
* **Target Desktop:** Omarchy (Arch Linux + Hyprland + Quickshell)
* **Location:** `~/.config/omarchy/plugins/icons` (symlinked from `~/Projects/omarchy-icons`)
* **Purpose:** Allows users to browse, install (via pacman), and apply GTK icon themes directly from the top status bar.

---

## 2. File Structure & Responsibilities

```
omarchy-icons/
├── manifest.json       # Plugin manifest (schemaVersion 1, kind: bar-widget, category: Appearance)
├── BarWidget.qml       # Bar button slot item, popout coordinator, IPC handler, loads Panel.qml
├── Panel.qml           # Main popup UI (extends qs.Ui.Panel), accordion list, pacman & gsettings logic
├── IconCatalog.js      # .pragma library containing verified icon theme definitions and package mappings
├── AGENTS.md           # Instructions for AI agents (this file)
├── README.md           # User-facing documentation
└── LICENSE             # MIT License
```

---

## 3. Architecture & Icon Subsystem Details

### The 5-Point Theme Synchronization
When the user clicks a theme variant in `Panel.qml`, `applyTheme(themeName)` runs a shell script that synchronizes the theme across all subsystem layers:

1. **GNOME / Wayland Settings:**
   ```bash
   gsettings set org.gnome.desktop.interface icon-theme "$THEME"
   ```
2. **GTK3 & GTK4 Settings:**
   Writes `[Settings]\ngtk-icon-theme-name=$THEME` into:
   - `~/.config/gtk-3.0/settings.ini`
   - `~/.config/gtk-4.0/settings.ini`
3. **Freedesktop / Qt Default Theme Inheritance:**
   Writes `[Icon Theme]\nInherits=$THEME` into:
   - `~/.icons/default/index.theme`
4. **Omarchy Menu (`AppLibrary`) Priority Symlinks:**
   Omarchy's `AppLibrary.qml` scans `$HOME/.local/share/icons` *before* `/usr/share/icons`.
   The script creates:
   ```bash
   DEST="$HOME/.local/share/icons/0-active-theme"
   rm -rf "$DEST"
   mkdir -p "$DEST"
   # Finds the theme's apps directory and creates shadow symlinks:
   cp -as "$tdir/$s/apps" "$DEST/apps"
   ```
   This ensures that all apps in the Omarchy Menu (`Super` → **Apps** / Search) immediately display the active theme's icons.
5. **Omarchy Desktop Theme Hook:**
   Writes `$THEME` to `~/.local/state/omarchy/current/theme/icons.theme` if present.

### Shell Reload on Apply
Upon exit code 0 of `applyProcess`, a timer triggers:
```bash
rm -rf "$HOME/.cache/quickshell/qmlcache" "$HOME/.cache/quickshell"/qtpipelinecache-*
omarchy-restart-shell
```

---

## 4. UI Patterns & Guidelines

* **Base Components:** Use Omarchy UI components from `/usr/share/omarchy/shell/Ui/`:
  - `Panel`: Base item with IPC target and open/close controller.
  - `KeyboardPanel`: Layer-shell popup card. Must specify `anchorItem`, `owner`, `bar`, `open`, `focusTarget`, `contentWidth`, `contentHeight`.
  - `PanelKeyCatcher`: Handles keyboard navigation (Esc, Tab).
  - `PanelHero`: Standard hero header with icon, title, and current theme meta.
  - `Button`: Standard button (`text`, `iconText`, `leftAlign`, `foreground`, `fontFamily`, `selected`, `iconSpinning`).
  - `TextField`: Search field (`font.family: root.contentFontFamily`, `foreground: root.contentForeground`).
  - `PanelSeparator`: 1px styled divider.

* **Accordion Selection:** Only **one group** may be expanded at a time (`expandedGroupIndex`). Clicking another group collapses the previously opened one.

* **Action Locking:** While `root.applying` or `root.installing` is true, all variant buttons are disabled (`enabled: !root.applying && !root.installing`), and an animated spinner icon (`\uf110`) is shown on the active button.

---

## 5. Quickshell & QML Critical Rules

1. **`TextField` does NOT have a top-level `fontFamily` property.**
   - ❌ `TextField { fontFamily: "..." }` → **Crashes QML scene.**
   - ✅ `TextField { font.family: "..." }` or omit to use default.
2. **`StdioCollector` Text Accumulation:**
   - In Quickshell, `StdioCollector.text` can retain previous output across multiple process runs. Always parse the *last line* of output:
     ```javascript
     var lines = raw.split("\n")
     var lastLine = lines[lines.length - 1].trim().replace(/^'|'$/g, "")
     ```
3. **QML Compilation Cache:**
   - Quickshell caches compiled QML bytecode in `~/.cache/quickshell/qmlcache/`.
   - After editing QML files, always clear cache and restart:
     ```bash
     rm -rf ~/.cache/quickshell/qmlcache ~/.cache/quickshell/qtpipelinecache-* && omarchy-restart-shell
     ```
4. **Validation:**
   - Always test plugin validation before committing:
     ```bash
     omarchy plugin validate /home/omarchy/Projects/omarchy-icons/
     ```

---

## 6. Security & Package Management

* **Allowlist:** Only packages explicitly declared in `allowedPackages` in `Panel.qml` may be installed or removed via `pkexec pacman`.
* **Privileged Actions:**
  - Install: `pkexec pacman -S --noconfirm <package>`
  - Remove: `pkexec pacman -R --noconfirm <package>`
* **Input Validation:** Theme names must match `/^[A-Za-z0-9_-]+$/` before being passed to shell commands.

---

## 7. How to Add New Icon Themes

1. Verify package availability in Arch repositories:
   ```bash
   pacman -Si <package-name>
   ```
2. Verify exact directory and `index.theme` names inside the package archive:
   ```bash
   bsdtar -tf <package.pkg.tar.zst> | grep "index.theme"
   ```
3. Add the theme group and its variants to [`IconCatalog.js`](file:///home/omarchy/Projects/omarchy-icons/IconCatalog.js).
4. If it requires a new pacman package, append it to `allowedPackages` in [`Panel.qml`](file:///home/omarchy/Projects/omarchy-icons/Panel.qml).
5. Update [`README.md`](file:///home/omarchy/Projects/omarchy-icons/README.md) table.
6. Validate with `omarchy plugin validate .` and restart shell.
