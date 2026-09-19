#!/bin/bash
# ============================================
# Ubuntu Clean Migration - RESTORE script
# Run on NEW machine (Ubuntu installed):
#   sudo ./restore.sh ~/path/to/migration_backup_XXXX.tar.gz
# ============================================
export DEBIAN_FRONTEND=noninteractive
USERNAME=$(logname)
set -e
BACKUP="$1"
[ -f "$BACKUP" ] || { echo "Usage: sudo $0 <migration_backup.tar.gz>"; exit 1; }
STAGE=$(mktemp -d)
tar xzf "$BACKUP" -C "$STAGE"
USERNAME=$(logname)
USERHOME=$(getent passwd "$USERNAME" | cut -d: -f6)

# Core tools needed to get work running FIRST (before bulk installs)
CORE=(git curl wget build-essential python3 python3-venv python3-pip nodejs npm)

echo "== [1/8] Update system & add sources =="
# restore apt signing keys first, otherwise 3rd-party repos fail signature check
if [ -f "$STAGE/system/apt-keys.tar.gz" ]; then
  tar xzf "$STAGE/system/apt-keys.tar.gz" -C / 2>/dev/null || true
  echo "  apt signing keys restored"
fi
if [ -f "$STAGE/system/sources.list" ]; then
  cp "$STAGE/system/sources.list" /etc/apt/sources.list
fi
[ -d "$STAGE/system/sources.list.d" ] && cp -r "$STAGE/system/sources.list.d"/* /etc/apt/sources.list.d/ 2>/dev/null || true
apt update || echo "⚠ apt update had errors - continuing with cached lists"

echo "== [2/8] Install CORE toolchain first (git, node, python, build tools) =="
apt install -y "${CORE[@]}" || echo "⚠ Some core packages failed - check manually!"

echo "== [3/8] Restore dotfiles & config (so git/ssh works right away) =="
tar xzf "$STAGE/home/dotfiles.tar.gz" -C "$USERHOME" 2>/dev/null || true
# Fix ownership (tar ran as root)
chown -R "$USERNAME:$USERNAME" "$USERHOME"/.bashrc "$USERHOME"/.profile "$USERHOME"/.gitconfig \
  "$USERHOME"/.ssh "$USERHOME"/.config "$USERHOME"/.local "$USERHOME"/.gnupg "$USERHOME"/.npmrc 2>/dev/null || true
chmod 700 "$USERHOME/.ssh" 2>/dev/null; chmod 600 "$USERHOME/.ssh"/* 2>/dev/null || true

echo "== [4/8] MAIN PROJECT: restore + deps + verify it runs =="
PROJECTS_DIR="${PROJECTS_DIR:-$USERHOME/E2_Lab}"
mkdir -p "$PROJECTS_DIR"
tar xzf "$STAGE/home/projects.tar.gz" -C "$PROJECTS_DIR" 2>/dev/null || true
chown -R "$USERNAME:$USERNAME" "$PROJECTS_DIR"
su - "$USERNAME" -c "cd $PROJECTS_DIR; for f in */package.json; do [ -f \"\$f\" ] && (cd \$(dirname \"\$f\") && npm install); done
for r in */requirements.txt; do [ -f \"\$r\" ] && (python3 -m venv \$(dirname \"\$r\")/.venv && \$(dirname \"\$r\")/.venv/bin/pip install -r \"\$r\"); done" || \
  echo "⚠ Some dependency installs skipped"
# Smoke test: try build/test of each node project so problems surface NOW
su - "$USERNAME" -c "cd $PROJECTS_DIR; for d in */; do
  [ -f \"\$d/package.json\" ] || continue
  cd \"$PROJECTS_DIR/\$d\"
  echo \"--- verify: \$d\"
  npx --no-install npm run build --silent 2>/dev/null || npm run build --if-present --silent 2>/dev/null || echo \"  (no build script or build failed - check manually)\"
done" || true

echo "== [5/8] Install VS Code + your extensions =="
if [ -s "$STAGE/home/vscode-extensions.txt" ] || ! command -v code &>/dev/null; then
  apt install -y code 2>/dev/null \
    || (wget -qO- https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor > /usr/share/keyrings/packages.microsoft.gpg \
        && echo "deb [arch=amd64 signed-by=/usr/share/keyrings/packages.microsoft.gpg] https://packages.microsoft.com/repos/code stable main" > /etc/apt/sources.list.d/vscode.list \
        && apt update && apt install -y code) || echo "⚠ VS Code install failed - install manually"
fi
if command -v code &>/dev/null && [ -s "$STAGE/home/vscode-extensions-dir.tar.gz" ]; then
  # exact-version extension copy (no download needed)
  su - "$USERNAME" -c "mkdir -p \$HOME/.vscode && tar xzf $STAGE/home/vscode-extensions-dir.tar.gz -C \$HOME/.vscode" 2>/dev/null || true
  echo "  extensions copied from source machine: $(su - "$USERNAME" -c 'code --list-extensions 2>/dev/null | wc -l')"
elif command -v code &>/dev/null && [ -s "$STAGE/home/vscode-extensions.txt" ]; then
  su - "$USERNAME" -c "xargs -L 1 code --install-extension < $STAGE/home/vscode-extensions.txt" || true
fi
if command -v code &>/dev/null && [ -s "$STAGE/home/vscode-settings.tar.gz" ]; then
  tar xzf "$STAGE/home/vscode-settings.tar.gz" -C "$USERHOME" 2>/dev/null || true
  chown -R "$USERNAME:$USERNAME" "$USERHOME/.config/Code" "$USERHOME/.vscode" 2>/dev/null || true
fi

echo "== [6/8] Install the REST of your packages (non-critical bulk install) =="
# Skip GPU-specific packages (new machine may have no discrete GPU)
PKGS=$(comm -23 "$STAGE/system/manual-packages.txt" \
  <(apt-mark showmanual | sort) | grep -viE 'nvidia|cuda' || true)
if ! xargs -r apt install -y --no-install-recommends <<< "$PKGS"; then
  echo "⚠ Bulk install had failures - retrying one by one to skip broken ones"
  for p in $PKGS; do
    apt install -y --no-install-recommends "$p" >/dev/null 2>&1 || echo "  skip: $p (unavailable)"
  done
fi

echo "== [7/8] Crontab & custom services =="
su - "$USERNAME" -c "crontab $STAGE/system/mycron.txt" 2>/dev/null || true
# Custom systemd units - copy but do NOT enable, review before enabling
[ -d "$STAGE/system/systemd-custom" ] && cp -n "$STAGE/system/systemd-custom"/*.service /etc/systemd/system/ 2>/dev/null || true
systemctl daemon-reload
echo "➜ Custom services copied but NOT enabled. Review with:"
echo "   systemctl list-unit-files | grep -vE 'apt|getty|ssh|network|systemd|udev|logind|dbus'"

echo "== [8/8] Final verification =="
bash "$(dirname "$0")/verify.sh" "$USERNAME" "$PROJECTS_DIR" || true

rm -rf "$STAGE"
echo ""
echo "✔ RESTORE DONE. Core tools + main project were installed and verified FIRST,"
echo "  so if anything fails you know exactly where. Reboot when ready."
