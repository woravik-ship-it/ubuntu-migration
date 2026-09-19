#!/bin/bash
# ============================================
# Ubuntu Clean Migration - BACKUP script
# Run on OLD machine: sudo ./backup.sh
# Output: ~/migration_backup_<date>.tar.gz
# ============================================
set -e
OUT="$HOME/migration_backup_$(date +%Y%m%d_%H%M)"
STAGE=$(mktemp -d)
mkdir -p "$STAGE"/{system,home,projects_meta}

echo "== [1/6] Package list (manual installs only - clean) =="
apt-mark showmanual > "$STAGE/system/manual-packages.txt"
dpkg --get-selections | grep -v deinstall > "$STAGE/system/all-packages.txt"
cp /etc/apt/sources.list "$STAGE/system/" 2>/dev/null || true
cp -r /etc/apt/sources.list.d "$STAGE/system/" 2>/dev/null || true

echo "== [2/6] Crontab & systemd custom services & apt keys =="
crontab -l > "$STAGE/system/mycron.txt" 2>/dev/null || echo "# no crontab" > "$STAGE/system/mycron.txt"
cp -r /etc/systemd/system "$STAGE/system/systemd-custom" 2>/dev/null || true
systemctl list-unit-files --state=enabled --no-pager > "$STAGE/system/enabled-services.txt"
tar czf "$STAGE/system/apt-keys.tar.gz" -C / etc/apt/keyrings etc/apt/trusted.gpg.d 2>/dev/null || true

echo "== [3/6] Dotfiles & config (exclude junk) =="
tar czf "$STAGE/home/dotfiles.tar.gz" \
  -C "$HOME" \
  --exclude='.cache' --exclude='.local/share/Trash' \
  --exclude='.npm' --exclude='.cargo/registry' \
  --exclude='.local/share/baloo' --exclude='*.log' \
  .bashrc .profile .bash_aliases .gitconfig .gitignore_global \
  .ssh .config .local/bin .gnupg .pki .npmrc .zshrc .vimrc 2>/dev/null || true

echo "== [4/6] VS Code settings & extension list =="
if command -v code &>/dev/null; then
  # snap version of code needs 'snap run', plain call may return nothing
  code --list-extensions > "$STAGE/home/vscode-extensions.txt" 2>/dev/null || true
  if [ ! -s "$STAGE/home/vscode-extensions.txt" ] && command -v snap &>/dev/null && snap list code &>/dev/null; then
    snap run code --list-extensions > "$STAGE/home/vscode-extensions.txt" 2>/dev/null || true
  fi
  wc -l < "$STAGE/home/vscode-extensions.txt" | xargs echo "  extensions found:"
  tar czf "$STAGE/home/vscode-settings.tar.gz" -C "$HOME" .config/Code/User 2>/dev/null || true
  # copy extensions folder itself (exact versions, no re-download needed)
  if [ -d "$HOME/.vscode/extensions" ]; then
    tar czf "$STAGE/home/vscode-extensions-dir.tar.gz" -C "$HOME/.vscode" extensions 2>/dev/null || true
  fi
fi

echo "== [5/6] Project list & project dirs (no node_modules/venv/build) =="
# Edit PROJECTS_DIR if your projects live elsewhere:
PROJECTS_DIR="${PROJECTS_DIR:-$HOME/E2_Lab}"
ls -d "$PROJECTS_DIR"/* > "$STAGE/projects_meta/project-list.txt" 2>/dev/null || true
if [ -d "$PROJECTS_DIR" ]; then
  tar czf "$STAGE/home/projects.tar.gz" -C "$PROJECTS_DIR" \
    --exclude='node_modules' --exclude='.venv' --exclude='venv' \
    --exclude='__pycache__' --exclude='dist' --exclude='build' \
    --exclude='.next' --exclude='target' --exclude='.cache' \
    --exclude='*.log' . 2>/dev/null || true
fi

echo "== [6/6] Pack everything =="
tar czf "$OUT.tar.gz" -C "$STAGE" .
rm -rf "$STAGE"
echo ""
echo "✔ DONE: $OUT.tar.gz"
echo "➜ Copy this file to a USB drive / scp to new machine, then run restore.sh there"
