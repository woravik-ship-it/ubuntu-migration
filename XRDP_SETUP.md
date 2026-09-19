# Ubuntu Remote Desktop (XRDP & XFCE) Setup Guide

คู่มือการติดตั้งและตั้งค่าการรีโมทหน้าจอ (Remote Desktop) บน Ubuntu ด้วย **XRDP** และเดสก์ท็อป **XFCE** เพื่อแก้ปัญหาจอดำหรือรีโมทไม่สำเร็จ

---

## 📋 สารบัญ
1. [ภาพรวมการเชื่อมต่อ](#1-ภาพรวมการเชื่อมต่อ)
2. [ขั้นตอนการติดตั้งฝั่งเซิร์ฟเวอร์ (Ubuntu)](#2-ขั้นตอนการติดตั้งฝั่งเซิร์ฟเวอร์-ubuntu)
3. [การแก้ไขปัญหา (Troubleshooting) ที่พบบ่อย](#3-การแก้ไขปัญหา-troubleshooting-ที่พบบ่อย)
4. [แอปพลิเคชันแนะนำสำหรับรีโมท](#4-แอปพลิเคชันแนะนำสำหรับรีโมท)

---

## 1. ภาพรวมการเชื่อมต่อ
* **IP Address ของเครื่องนี้:** `192.168.1.57`
* **โปรโตคอลที่รองรับ:** 
  * **RDP (Port 3389):** รีโมทแบบเห็นหน้าจอเดสก์ท็อป (ใช้ XFCE)
  * **SSH (Port 22):** รีโมทแบบพิมพ์คำสั่ง Terminal

---

## 2. ขั้นตอนการติดตั้งฝั่งเซิร์ฟเวอร์ (Ubuntu)

รันคำสั่งเหล่านี้ผ่าน Terminal ของเครื่องเซิร์ฟเวอร์ (ด้วยสิทธิ์ `sudo`):

### 2.1 ติดตั้ง XRDP และ OpenSSH Server
```bash
sudo apt update
sudo apt install -y xrdp openssh-server dbus-x11
```

### 2.2 ติดตั้งเดสก์ท็อป XFCE (แนะนำสำหรับ XRDP เพื่อความเสถียร)
```bash
sudo apt install -y xfce4 xfce4-session
```

### 2.3 เปิดใช้งานและเริ่มบริการ XRDP
```bash
sudo systemctl enable --now xrdp
sudo systemctl restart xrdp
```

### 2.4 เปิด Firewall ให้พอร์ต RDP และ SSH ผ่านได้
```bash
sudo ufw allow 3389/tcp
sudo ufw allow 22/tcp
sudo ufw reload
```

---

## 3. การแก้ไขปัญหา (Troubleshooting) ที่พบบ่อย

### ปัญหา 1: ใส่รหัสผ่านแล้วเด้งออก / หน้าจอค้าง / Error 127
* **สาเหตุ:** สคริปต์เริ่มต้นเซสชันไม่พบหน้าจอเดสก์ท็อป หรือตัวแปร D-Bus ขัดข้อง
* **วิธีแก้:** ตั้งค่าคอนฟิกไฟล์ `/etc/xrdp/startwm.sh` ให้เรียกใช้งาน XFCE ผ่าน `dbus-launch` ดังนี้:

```bash
sudo bash -c 'cat << '\''EOF'\'' > /etc/xrdp/startwm.sh
#!/bin/sh
unset DBUS_SESSION_BUS_ADDRESS
unset XDG_RUNTIME_DIR
if [ -r /etc/profile ]; then
    . /etc/profile
fi
exec dbus-launch --exit-with-session startxfce4
EOF
sudo chmod +x /etc/xrdp/startwm.sh
sudo systemctl restart xrdp
```

---

## 4. แอปพลิเคชันแนะนำสำหรับรีโมท (Client)

ฝั่งเครื่องที่ใช้รีโมทเข้ามา สามารถใช้โปรแกรมเหล่านี้:
* **Windows:** Remote Desktop Connection (`mstsc`)
* **Ubuntu / Linux:** **Remmina** (รองรับทั้ง RDP และ SSH)
  * ติดตั้ง Remmina บน Ubuntu: `sudo apt install remmina`
  * วิธีใช้: เปิดแอป -> เลือกโปรโตคอลเป็น **RDP** -> ใส่ IP `192.168.1.57` -> กด Connect
