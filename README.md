# Icon Theme Switcher for Omarchy

Browse, download, and apply GTK icon themes directly from the Omarchy bar.

![bar-widget](https://img.shields.io/badge/kind-bar--widget-blue)
![license](https://img.shields.io/badge/license-MIT-green)

## Features

- **Browse** a curated catalog of popular icon themes (Papirus, Tela Circle, Pop, Obsidian, and more)
- **Install** icon theme packages from Arch repos via pacman (with polkit authentication)
- **Apply** any installed icon theme variant with a single click
- **Dark/Light variants** — each theme group shows all available variants with mode badges
- **Search** to quickly find themes
- **Pre-installed themes** — Yaru, Adwaita, and Breeze variants are listed out of the box

## Installation

```bash
omarchy plugin add https://github.com/YOUR_USERNAME/omarchy-icons.git
omarchy plugin enable icons
```

The widget will appear in the bar. Click it to open the icon theme panel.

## Usage

1. Click the palette icon (🎨) in the bar
2. Browse available icon themes in the panel
3. Click a group to expand and see Dark/Light variants
4. For themes not yet installed, click **Install package** to download via pacman
5. Click any variant to apply it as your GTK icon theme
6. The active theme is shown with a checkmark (✓)

## Supported Icon Themes

| Theme | Package | Variants |
|-------|---------|----------|
| Papirus | `papirus-icon-theme` | Papirus Dark, Papirus Light |
| Tela Circle | `tela-circle-icon-theme-all` | 15 color schemes (Standard, Dracula, Nord, Blue, Brown, etc.) |
| Pop | `pop-icon-theme` | Pop (adaptive) |
| Deepin / Bloom | `deepin-icon-theme` | Bloom, Bloom-dark, Bloom-classic, Vintage, Sea |
| Cosmic | `cosmic-icon-theme` | Cosmic |
| Elementary | `elementary-icon-theme` | elementary |
| Oxygen | `oxygen-icons` | Oxygen |
| Yaru | pre-installed | 20 color/dark variants |
| Adwaita | pre-installed | Adwaita |
| Breeze | pre-installed | Breeze, Breeze-dark |

## How it Works

- Icon themes are installed via `pkexec pacman -S` (prompts for password)
- Themes are applied via `gsettings set org.gnome.desktop.interface icon-theme`
- The plugin reads installed themes from `/usr/share/icons/`, `~/.local/share/icons/`, and `~/.icons/`

## Note

When you switch Omarchy themes (`omarchy theme set`), the icon theme may be overridden by the theme's `icons.theme` file. This is standard Omarchy behavior — the icon theme is part of the overall desktop theme.

## License

MIT
