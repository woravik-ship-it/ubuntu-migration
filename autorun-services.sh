#!/bin/bash
# ============================================
# Ubuntu Clean Migration - PROJECT AUTORUN services
# ดู / ควบคุม บริการ user-level systemd (systemd --user) ที่ autorun จากโปรเจกต์
#
# บริการของโปรเจกต์ในเครื่องนี้ (ติดตั้งจาก repo ของแต่ละโปรเจกต์):
#   cline-dashboard.service        -> E2_Lab/cline-dashboard  (เว็บมอนิเตอร์ พอร์ต 3001)
#   cline-dashboard-tunnel.service -> E2_Lab/cline-dashboard  (Cloudflare tunnel + ส่งลิงก์เข้า Telegram)
#   cline-hub.service              -> E2_Lab/cline-bot        (supervise cline hub daemon)
#   cline-telegram.service         -> E2_Lab/cline-bot        (ลงทะเบียน Telegram connector กับ hub)
#
# ต้องมี Linger=yes เพื่อให้บริการเริ่มเองตอนบูตโดยไม่ต้อง login:
#   loginctl enable-linger $USER
#
# วิธีใช้:
#   ./autorun-services.sh                 # list (ค่าเริ่มต้น)
#   ./autorun-services.sh list            # รายชื่อ + สถานะ enabled/active
#   ./autorun-services.sh status          # สถานะละเอียด + health check (hub, dashboard, tunnel)
#   ./autorun-services.sh verify          # ตรวจความพร้อมของระบบ autorun (exit 1 ถ้ามีปัญหา)
#   ./autorun-services.sh start|stop|restart|enable|disable [unit ...]
# ============================================

set -uo pipefail

# unit ที่ autorun จากโปรเจกต์ + คำอธิบายสั้น
UNITS=(
    cline-dashboard.service
    cline-dashboard-tunnel.service
    cline-hub.service
    cline-telegram.service
)
declare -A UNIT_DESC=(
    [cline-dashboard.service]="Cline Dashboard (web monitor :3001)"
    [cline-dashboard-tunnel.service]="Cloudflare tunnel + Telegram link"
    [cline-hub.service]="Cline Hub daemon (supervisor)"
    [cline-telegram.service]="Cline Telegram connector"
)

CLINE_BIN="${CLINE_BIN:-$HOME/.npm-global/bin/cline}"
DASHBOARD_URL="${DASHBOARD_URL:-http://localhost:3001}"
UNIT_DIR="$HOME/.config/systemd/user"
PASS=0
FAIL=0

ok()  { echo "✔ $1"; PASS=$((PASS + 1)); }
bad() { echo "✘ $1  (แก้ไข: $2)"; FAIL=$((FAIL + 1)); }

svc() { systemctl --user "$@"; }

# --- list ---------------------------------------------------------------------
cmd_list() {
    printf '%-32s %-10s %-20s %s\n' UNIT ENABLED STATE DESCRIPTION
    for unit in "${UNITS[@]}"; do
        if [ ! -f "$UNIT_DIR/$unit" ]; then
            printf '%-32s %-10s %-20s %s\n' "$unit" "-" "not installed" "${UNIT_DESC[$unit]}"
            continue
        fi
        local enabled active
        enabled="$(svc is-enabled "$unit" 2>/dev/null || true)"
        active="$(svc is-active "$unit" 2>/dev/null || true)"
        printf '%-32s %-10s %-20s %s\n' \
            "$unit" "${enabled:-unknown}" "${active:-unknown}" "${UNIT_DESC[$unit]}"
    done
    echo
    echo "Linger: $(loginctl show-user "$USER" 2>/dev/null | grep -o 'Linger=[a-z]*' || echo 'Linger=?')"
}

# --- status -------------------------------------------------------------------
cmd_status() {
    svc status "${UNITS[@]}" --no-pager || true

    echo
    echo "=== health check ==="
    if [ -x "$CLINE_BIN" ]; then
        echo "cline CLI: $("$CLINE_BIN" --version 2>/dev/null)"
        echo "hub status: $("$CLINE_BIN" hub status 2>/dev/null)"
    else
        echo "cline CLI: ไม่พบที่ $CLINE_BIN"
    fi
    echo "dashboard:  HTTP $(curl -s -o /dev/null -w '%{http_code}' --max-time 5 "$DASHBOARD_URL/" 2>/dev/null || echo 000) (401 = ทำงานแต่ต้องใส่รหัส)"
    local url
    url="$(grep -oE 'https://[a-z0-9-]+\.trycloudflare\.com' "$HOME/E2_Lab/cline-dashboard/tunnel.log" 2>/dev/null | head -1)"
    echo "public URL: ${url:-ไม่พบใน tunnel.log}"
}

# --- verify -------------------------------------------------------------------
cmd_verify() {
    PASS=0
    FAIL=0
    echo "=== Project autorun readiness check ==="

    for unit in "${UNITS[@]}"; do
        if [ -f "$UNIT_DIR/$unit" ]; then
            ok "$unit installed"
        else
            bad "$unit installed" "รันสคริปต์ติดตั้งของโปรเจกต์นั้น"
        fi
        if svc is-enabled "$unit" >/dev/null 2>&1; then
            ok "$unit enabled"
        else
            bad "$unit enabled" "systemctl --user enable $unit"
        fi
    done

    if loginctl show-user "$USER" 2>/dev/null | grep -q 'Linger=yes'; then
        ok "Linger=yes (เริ่มเองตอนบูตได้โดยไม่ต้อง login)"
    else
        bad "Linger=yes" "loginctl enable-linger $USER"
    fi

    if [ -x "$CLINE_BIN" ]; then
        ok "cline CLI: $CLINE_BIN"
    else
        bad "cline CLI" "npm install -g cline"
    fi

    for unit in "${UNITS[@]}"; do
        if svc is-active "$unit" >/dev/null 2>&1; then
            ok "$unit active"
        else
            bad "$unit active" "systemctl --user restart $unit"
        fi
    done

    local code
    code="$(curl -s -o /dev/null -w '%{http_code}' --max-time 5 "$DASHBOARD_URL/" 2>/dev/null || echo 000)"
    if [ -n "$code" ] && [ "$code" != "000" ]; then
        ok "dashboard ตอบที่ $DASHBOARD_URL (HTTP $code)"
    else
        bad "dashboard ตอบที่ $DASHBOARD_URL" "systemctl --user restart cline-dashboard.service"
    fi

    if [ -x "$CLINE_BIN" ] && "$CLINE_BIN" hub status 2>/dev/null | grep -q '"running"[[:space:]]*:[[:space:]]*true'; then
        ok "hub daemon running"
    else
        bad "hub daemon running" "systemctl --user restart cline-hub.service"
    fi

    echo
    echo "=================================="
    echo "PASS: $PASS   FAIL: $FAIL"
    [ "$FAIL" -eq 0 ]
}

# --- control ------------------------------------------------------------------
cmd_control() {
    local action="$1"; shift
    local targets=("$@")
    [ "${#targets[@]}" -eq 0 ] && targets=("${UNITS[@]}")
    svc "$action" "${targets[@]}"
}

case "${1:-list}" in
    list)    cmd_list ;;
    status)  cmd_status ;;
    verify)  cmd_verify ;;
    start|stop|restart|enable|disable) cmd_control "$@" ;;
    -h|--help) sed -n '2,21p' "$0" ;;
    *) echo "unknown command: $1" >&2; sed -n '2,21p' "$0" >&2; exit 2 ;;
esac
