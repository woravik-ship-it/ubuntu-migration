# Ubuntu Clean Migration & Desktop Clone Scripts

ชุดสคริปต์สำหรับการสำรองข้อมูล ย้ายระบบ (Migration) และคัดลอกหน้าตาเดสก์ท็อป (GNOME Desktop Look) สำหรับ Ubuntu 24.04/26.04 LTS

## รายการสคริปต์

- **`backup.sh`**: สำรองข้อมูลแบบสะอาด ( Package List, Dotfiles, VS Code Settings & Extensions, Project Folders โดยตัด `node_modules`, `.venv`, `cache` ออก)
- **`restore.sh`**: กู้คืนระบบบนเครื่องใหม่แบบ Core-first (ติดตั้ง Toolchain หลัก -> ย้ายโปรเจกต์ -> VS Code -> โปรแกรมทั้งหมด -> ตรวจสอบระบบ)
- **`verify.sh`**: ตรวจสอบความพร้อมของระบบ เครื่องมือ (Git, Node, Python, VS Code), SSH/GitHub และโปรเจกต์
- **`desktop-look.sh`**: บันทึกและคืนค่าหน้าตา GNOME Desktop (`save` / `apply`) ได้แก่ dconf, extensions, วอลเปเปอร์, และปุ่มสลับภาษา
- **`autorun-services.sh`**: ดู/ควบคุม บริการ user-level systemd ที่ autorun จากโปรเจกต์ (Cline Dashboard, Tunnel, Hub, Telegram)

## คู่มือ (docs)

- **`XRDP_SETUP.md`**: รีโมทหน้าจอด้วย XRDP + เดสก์ท็อป XFCE (แก้จอดำ/รีโมทไม่ติด)
- **`RUSTDESK_SETUP.md`**: ติดตั้ง/ดูแล **RustDesk Server (self-hosted, hbbs + hbbr)** บนเครื่องนี้
  (ID/relay ของตัวเอง, พอร์ต 21115-21119, คีย์บังคับ, วิธีตั้งค่าฝั่ง client + port forward สำหรับใช้จากนอกวง)

## บริการที่ Autorun จากโปรเจกต์ (systemd --user)

ติดตั้งโดย repo ของแต่ละโปรเจกต์ (`E2_Lab/cline-dashboard/install-systemd.sh`, `E2_Lab/cline-bot/install-services.sh`)
แต่ตัว unit ต้อง `enable` ไว้ที่ user นี้ และต้องมี `Linger=yes` เพื่อให้เริ่มเองตอนบูตโดยไม่ต้อง login

| Unit | โปรเจกต์ | หน้าที่ |
| --- | --- | --- |
| `cline-dashboard.service` | `E2_Lab/cline-dashboard` | เว็บมอนิเตอร์ Cline session (พอร์ต 3001, Basic auth) |
| `cline-dashboard-tunnel.service` | `E2_Lab/cline-dashboard` | Cloudflare quick tunnel + ส่งลิงก์เข้า Telegram ทุกครั้งที่รีสตาร์ท |
| `cline-hub.service` | `E2_Lab/cline-bot` | supervise `cline hub` daemon (`run-hub.sh`, `Restart=always`) |
| `cline-telegram.service` | `E2_Lab/cline-bot` | ลงทะเบียน Telegram connector ให้ hub ดูแล (`wait-for-hub.sh` ก่อน) |

สิ่งที่ต้องมีในเครื่อง (นอกเหนือจาก unit):
```bash
npm install -g cline          # ให้ได้ ~/.npm-global/bin/cline (hub/connect ใช้ตัวนี้)
loginctl enable-linger $USER  # ให้ user service เริ่มเองตอนบูต
```
ตรวจความพร้อมทั้งหมดด้วย `./autorun-services.sh verify` (ควรได้ FAIL: 0)


## วิธีใช้งาน

### 1. สำรองข้อมูล (เครื่องเก่า)
```bash
./backup.sh
```

### 2. กู้คืนระบบ (เครื่องใหม่)
```bash
sudo ./restore.sh /path/to/migration_backup_XXXX.tar.gz
```

### 3. บันทึก/คัดลอกหน้าตา Desktop
```bash
# บันทึก
./desktop-look.sh save

# คืนค่าบนเครื่องใหม่
./desktop-look.sh apply
```

### 4. ตรวจสอบความพร้อม
```bash
./verify.sh
```
