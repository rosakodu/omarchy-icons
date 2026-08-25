#!/bin/bash

# icons-helper.sh — helper for the Omarchy icons plugin
# Handles icon theme package management via pacman.
#
# Usage:
#   icons-helper.sh check  <package>        — prints "installed" or "not-installed"
#   icons-helper.sh install <package>        — installs package via pkexec pacman
#   icons-helper.sh remove  <package>        — removes package via pkexec pacman
#   icons-helper.sh current                  — prints current GTK icon theme name
#   icons-helper.sh apply   <theme-name>     — applies a GTK icon theme via gsettings
#   icons-helper.sh list-installed           — lists installed icon theme directories

set -o pipefail

ACTION="$1"
ARG="$2"

# Allowlist of known safe pacman package names to prevent injection.
ALLOWED_PACKAGES=(
  "papirus-icon-theme"
  "tela-circle-icon-theme-all"
  "tela-circle-icon-theme-black"
  "tela-circle-icon-theme-blue"
  "tela-circle-icon-theme-green"
  "tela-circle-icon-theme-grey"
  "tela-circle-icon-theme-orange"
  "tela-circle-icon-theme-pink"
  "tela-circle-icon-theme-purple"
  "tela-circle-icon-theme-red"
  "tela-circle-icon-theme-yellow"
  "pop-icon-theme"
  "obsidian-icon-theme"
  "cosmic-icon-theme"
  "elementary-icon-theme"
)

is_allowed_package() {
  local pkg="$1"
  for allowed in "${ALLOWED_PACKAGES[@]}"; do
    if [[ "$pkg" == "$allowed" ]]; then
      return 0
    fi
  done
  return 1
}

case "$ACTION" in
  check)
    if [[ -z "$ARG" ]]; then
      echo "error: missing package name"
      exit 1
    fi
    if pacman -Q "$ARG" &>/dev/null; then
      echo "installed"
    else
      echo "not-installed"
    fi
    ;;

  install)
    if [[ -z "$ARG" ]]; then
      echo "error: missing package name"
      exit 1
    fi
    if ! is_allowed_package "$ARG"; then
      echo "error: package not in allowlist: $ARG"
      exit 1
    fi
    pkexec pacman -S --noconfirm "$ARG" 2>&1
    ;;

  remove)
    if [[ -z "$ARG" ]]; then
      echo "error: missing package name"
      exit 1
    fi
    if ! is_allowed_package "$ARG"; then
      echo "error: package not in allowlist: $ARG"
      exit 1
    fi
    pkexec pacman -R --noconfirm "$ARG" 2>&1
    ;;

  current)
    gsettings get org.gnome.desktop.interface icon-theme 2>/dev/null | tr -d "'"
    ;;

  apply)
    if [[ -z "$ARG" ]]; then
      echo "error: missing theme name"
      exit 1
    fi
    # Validate theme name: only alphanumeric, dash, underscore allowed
    if [[ ! "$ARG" =~ ^[A-Za-z0-9_-]+$ ]]; then
      echo "error: invalid theme name"
      exit 1
    fi
    # Check that the theme directory actually exists
    if [[ ! -d "/usr/share/icons/$ARG" ]] && \
       [[ ! -d "$HOME/.local/share/icons/$ARG" ]] && \
       [[ ! -d "$HOME/.icons/$ARG" ]]; then
      echo "error: theme directory not found: $ARG"
      exit 1
    fi
    gsettings set org.gnome.desktop.interface icon-theme "$ARG"
    echo "applied"
    ;;

  list-installed)
    # Print names of directories in /usr/share/icons that have an index.theme
    for d in /usr/share/icons/*/; do
      name=$(basename "$d")
      [[ -f "$d/index.theme" ]] && echo "$name"
    done
    for d in "$HOME/.local/share/icons"/*/; do
      name=$(basename "$d")
      [[ -f "$d/index.theme" ]] && echo "$name"
    done
    for d in "$HOME/.icons"/*/; do
      name=$(basename "$d")
      [[ -f "$d/index.theme" ]] && echo "$name"
    done
    ;;

  check-all)
    # Check all allowlisted packages at once, output "package|status" per line
    for pkg in "${ALLOWED_PACKAGES[@]}"; do
      if pacman -Q "$pkg" &>/dev/null; then
        echo "$pkg|installed"
      else
        echo "$pkg|not-installed"
      fi
    done
    ;;

  *)
    echo "Usage: icons-helper.sh {check|install|remove|current|apply|list-installed|check-all} [arg]"
    exit 1
    ;;
esac
