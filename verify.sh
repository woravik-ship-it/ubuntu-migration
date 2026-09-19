#!/bin/bash
# ============================================
# Ubuntu Clean Migration - VERIFY script
# Check that the new machine is ready to work.
# Run: ./verify.sh [username] [projects_dir]
# ============================================
USERNAME="${1:-$(logname 2>/dev/null || echo $SUDO_USER)}"
PROJECTS_DIR="${2:-$(getent passwd "$USERNAME" | cut -d: -f6)/E2_Lab}"
USERHOME=$(getent passwd "$USERNAME" | cut -d: -f6)
# Run user-level commands as that user without su (avoids PAM hangs)
asuser() { HOME="$USERHOME" sudo -u "$USERNAME" env HOME="$USERHOME" "$@"; }
PASS=0; FAIL=0

check() { # name, command
  if eval "$2" &>/dev/null; then
    echo "✔ $1"; PASS=$((PASS+1))
  else
    echo "✘ $1  (run: $3)"; FAIL=$((FAIL+1))
  fi
}

echo "=== System readiness check ==="
check "git installed" "git --version" "sudo apt install git"
check "git identity configured" "asuser sh -c 'git config user.email'" "git config --global user.email you@example.com"
check "node installed" "node --version" "sudo apt install nodejs npm or use nvm"
check "npm works" "npm --version" "sudo apt install npm"
check "python3 works" "python3 --version" "sudo apt install python3"
check "pip works" "python3 -m pip --version" "sudo apt install python3-pip"
check "VS Code installed" "code --version" "sudo apt install code"

echo ""
echo "=== SSH / GitHub access ==="
check "ssh keys present" "ls /home/$USERNAME/.ssh/id_* >/dev/null 2>&1" "copy ~/.ssh from backup (restore.sh does this)"
check "github reachable via ssh" "asuser sh -c 'timeout 10 ssh -o BatchMode=yes -o StrictHostKeyChecking=no -o ConnectTimeout=5 -T git@github.com'" "test ssh -T git@github.com (exit 1 with 'Hi <user>!' is OK)"

echo ""
echo "=== Projects ==="
if [ -d "$PROJECTS_DIR" ]; then
  echo "✔ projects dir exists: $PROJECTS_DIR"; PASS=$((PASS+1))
  for d in "$PROJECTS_DIR"/*/; do
    name=$(basename "$d")
    if [ -f "$d/package.json" ]; then
      check "$name deps installed" "test -d $d/node_modules" "cd $d && npm install"
      check "$name git repo ok" "asuser sh -c 'cd $d && git status'" "cd $d && git status (check remote)"
    elif [ -f "$d/requirements.txt" ]; then
      check "$name venv present" "test -d $d/.venv" "cd $d && python3 -m venv .venv && .venv/bin/pip install -r requirements.txt"
    fi
  done
else
  echo "✘ projects dir missing: $PROJECTS_DIR"; FAIL=$((FAIL+1))
fi

echo ""
echo "=== Cron ==="
check "crontab restored" "asuser sh -c 'crontab -l' | grep -v '^#' | grep -q ." "crontab -l (empty is OK if you had none)"

echo ""
echo "================================"
echo "PASS: $PASS   FAIL: $FAIL"
echo "Fix any ✘ items above, then you are ready to work."
