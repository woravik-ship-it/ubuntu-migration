# Ubuntu Clean Migration & Desktop Clone Scripts

ชุดสคริปต์สำหรับการสำรองข้อมูล ย้ายระบบ (Migration) และคัดลอกหน้าตาเดสก์ท็อป (GNOME Desktop Look) สำหรับ Ubuntu 24.04/26.04 LTS

## รายการสคริปต์

- **`backup.sh`**: สำรองข้อมูลแบบสะอาด ( Package List, Dotfiles, VS Code Settings & Extensions, Project Folders โดยตัด `node_modules`, `.venv`, `cache` ออก)
- **`restore.sh`**: กู้คืนระบบบนเครื่องใหม่แบบ Core-first (ติดตั้ง Toolchain หลัก -> ย้ายโปรเจกต์ -> VS Code -> โปรแกรมทั้งหมด -> ตรวจสอบระบบ)
- **`verify.sh`**: ตรวจสอบความพร้อมของระบบ เครื่องมือ (Git, Node, Python, VS Code), SSH/GitHub และโปรเจกต์
- **`desktop-look.sh`**: บันทึกและคืนค่าหน้าตา GNOME Desktop (`save` / `apply`) ได้แก่ dconf, extensions, วอลเปเปอร์, และปุ่มสลับภาษา

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
