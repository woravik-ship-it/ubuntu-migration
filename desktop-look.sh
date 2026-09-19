#!/bin/bash
# ============================================================
# Desktop Look Cloner (GNOME)
#   save  -> capture current desktop look into ./look-backup
#   apply -> apply captured look onto this machine
#
# Usage:
#   ./desktop-look.sh save
#   ./desktop-look.sh apply [look-backup-dir]
#
# NOTE: after "apply" you MUST log out and log back in
#       (GNOME only scans extensions at session start)
# ============================================================
set -e
MODE="${1:-}"
DIR="${2:-$(dirname "$0")/look-backup}"
USERNAME=$(logname 2>/dev/null || echo "${SUDO_USER:-$USER}")
USERHOME=$(getent passwd "$USERNAME" | cut -d: -f6)

# helper: run gsettings/dconf inside the real user session (gotcha: root has no D-Bus)
asuser() {
  local dbus
  dbus=$(grep -z '^DBUS_SESSION_BUS_ADDRESS=' "/proc/$(loginctl show-user "$USERNAME" -p Leader --value 2>/dev/null | head -1)/environ" 2>/dev/null | tr -d '\0' | cut -d= -f2-)
  [ -z "$dbus" ] && dbus="unix:path=/run/user/$(id -u "$USERNAME")/bus"
  su "$USERNAME" -s /bin/bash -c "DBUS_SESSION_BUS_ADDRESS='$dbus' $*"
}

if [ "$MODE" = "save" ]; then
  mkdir -p "$DIR"
  echo "== saving desktop look to $DIR"
  asuser "dconf dump /org/gnome/" > "$DIR/gnome-settings.ini"
  mkdir -p "$DIR/extensions"
  cp -a "$USERHOME/.local/share/gnome-shell/extensions/." "$DIR/extensions/" 2>/dev/null || true
  mkdir -p "$DIR/applications" "$DIR/icons"
  cp -a "$USERHOME"/.local/share/applications/*.desktop "$DIR/applications/" 2>/dev/null || true
  cp -a "$USERHOME"/.local/share/icons/*.png "$USERHOME"/.local/share/icons/*.svg "$DIR/icons/" 2>/dev/null || true
  # remember wallpaper file path so we can copy it too
  asuser "gsettings get org.gnome.desktop.background picture-uri" | tr -d "'" | sed 's|^file://||' > "$DIR/wallpaper.path"
  w=$(cat "$DIR/wallpaper.path")
  [ -f "$w" ] && cp "$w" "$DIR/wallpaper$(echo "$w" | sed 's/.*\(\.[a-zA-Z]*\)$/\1/')"
  echo "--- captured:"
  ls "$DIR"
  echo "SAVE_DONE"

elif [ "$MODE" = "apply" ]; then
  [ -d "$DIR" ] || { echo "no look-backup dir: $DIR"; exit 1; }
  echo "== applying desktop look from $DIR"
  # extensions
  mkdir -p "$USERHOME/.local/share/gnome-shell/extensions"
  cp -a "$DIR/extensions/." "$USERHOME/.local/share/gnome-shell/extensions/" 2>/dev/null || true
  chown -R "$USERNAME:$USERNAME" "$USERHOME/.local/share/gnome-shell"
  chmod 700 "$USERHOME/.local/share/gnome-shell"
  # launchers + icons
  mkdir -p "$USERHOME/.local/share/applications" "$USERHOME/.local/share/icons"
  cp -a "$DIR/applications/." "$USERHOME/.local/share/applications/" 2>/dev/null || true
  cp -a "$DIR/icons/." "$USERHOME/.local/share/icons/" 2>/dev/null || true
  # wallpaper
  if [ -s "$DIR/wallpaper.path" ]; then
    wp=$(cat "$DIR/wallpaper.path")
    if [ -f "$DIR/wallpaper" ]; then
      mkdir -p "$USERHOME/Pictures/Wallpapers"
      cp "$DIR/wallpaper" "$USERHOME/Pictures/Wallpapers/$(basename "$wp")"
      chown -R "$USERNAME:$USERNAME" "$USERHOME/Pictures"
      wp="$USERHOME/Pictures/Wallpapers/$(basename "$wp")"
    fi
    asuser "gsettings set org.gnome.desktop.background picture-uri 'file://$wp'"
    asuser "gsettings set org.gnome.desktop.background picture-uri-dark 'file://$wp'"
  fi
  # full dconf (dock position, theme, fonts, keybindings ...)
  [ -s "$DIR/gnome-settings.ini" ] && asuser "dconf load /org/gnome/" < "$DIR/gnome-settings.ini" && echo "  dconf loaded"
  chown -R "$USERNAME:$USERNAME" "$USERHOME/.config" 2>/dev/null || true
  echo
  echo "  current values:"
  asuser "gsettings get org.gnome.shell enabled-extensions" || true
  asuser "gsettings get org.gnome.desktop.wm.keybindings switch-input-source" || true
  echo
  echo "== IMPORTANT: log out and log back in now."
  echo "   GNOME scans extensions only when a session starts,"
  echo "   so the panel/dock/indicators appear after the next login."
  echo "APPLY_DONE"
else
  sed -n '2,20p' "$0"
  exit 1
fi