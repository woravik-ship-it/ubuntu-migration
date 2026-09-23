# RustDesk Server (Self-hosted) Setup Guide

คู่มือติดตั้ง/ดูแล **RustDesk Server OSS** (hbbs + hbbr) บนเครื่อง **E2SV** (Ubuntu 26.04.1 LTS)
ใช้เป็นช่องทางรีโมทของตัวเอง ไม่พึ่งบริการภายนอก (AnyDesk) — ติดตั้งจริงเมื่อ **2026-09-23**

---

## 📋 สารบัญ
1. [ภาพรวมและค่าที่ใช้จริง](#1-ภาพรวมและค่าที่ใช้จริง)
2. [ติดตั้ง (แบบที่ทำไว้)](#2-ติดตั้ง-แบบที่ทำไว้)
3. [ค่าที่ตั้งเพิ่ม (systemd drop-in)](#3-ค่าที่ตั้งเพิ่ม-systemd-drop-in)
4. [จัดการ service / อัปเดต](#4-จัดการ-service--อัปเดต)
5. [ตั้งค่าฝั่ง client](#5-ตั้งค่าฝั่ง-client)
6. [ใช้งานจากนอกวง (WAN)](#6-ใช้งานจากนอกวง-wan)
7. [แก้ปัญหา (Troubleshooting)](#7-แก้ปัญหา-troubleshooting)

---

## 1. ภาพรวมและค่าที่ใช้จริง

| ส่วน | หน้าที่ | พอร์ต |
| --- | --- | --- |
| `hbbs` (ID/Rendezvous) | ให้ client ลงทะเบียน ID + จับคู่ | 21115 tcp (NAT test), **21116 tcp+udp**, 21118 tcp (websocket) |
| `hbbr` (Relay) | ส่งข้อมูลต่อเมื่อต่อตรงไม่ได้ | **21117 tcp**, 21119 tcp (websocket) |

ค่าจริงของเครื่องนี้ (2026-09-23)

```
IP ในวง      : 192.168.1.57
Public key   : ls7Y+iY4TauJqHLeOjwx+wO5PiYKf0vsYf56rMtOPQk=
ข้อมูล/คีย์  : /var/lib/rustdesk-server/   (id_ed25519, id_ed25519.pub, db_v2.sqlite3)
log          : /var/log/rustdesk-server/  (hbbs.log, hbbs.error, hbbr.log, hbbr.error)
service      : rustdesk-hbbs.service, rustdesk-hbbr.service (enable + start อัตโนมัติ)
เวอร์ชัน     : rustdesk-server 1.1.16 (amd64)
```

> หมายเหตุ: เครื่องนี้ยัง**ไม่ได้ติดตั้ง RustDesk client** (ตัวควบคุม/ตัวถูกควบคุม) — ตัวเซิร์ฟเวอร์ให้บริการ ID/relay เท่านั้น

---

## 2. ติดตั้ง (แบบที่ทำไว้)

ใช้แพ็กเกจ `.deb` ทางการจาก GitHub release (ไม่ต้องใช้ Docker):

```bash
cd /tmp
V=1.1.16
curl -sSLO "https://github.com/rustdesk/rustdesk-server/releases/download/$V/rustdesk-server-hbbs_${V}_amd64.deb"
curl -sSLO "https://github.com/rustdesk/rustdesk-server/releases/download/$V/rustdesk-server-hbbr_${V}_amd64.deb"
sudo apt install -y ./rustdesk-server-hbbs_${V}_amd64.deb ./rustdesk-server-hbbr_${V}_amd64.deb
```

แพ็กเกจติดตั้ง systemd unit ให้เอง (`/usr/lib/systemd/system/rustdesk-*.service`)
พร้อม `enable` + `start` และสร้าง `/var/lib/rustdesk-server` + `/var/log/rustdesk-server` ให้
(hbbs จะสร้างคีย์ `id_ed25519` / `id_ed25519.pub` ตั้งแต่รันครั้งแรก)

---

## 3. ค่าที่ตั้งเพิ่ม (systemd drop-in)

ไม่แก้ unit ของแพ็กเกจ — ใช้ drop-in เพื่อให้อัปเดตแพ็กเกจแล้วค่าคงอยู่

`/etc/systemd/system/rustdesk-hbbs.service.d/override.conf`

```ini
[Service]
ExecStart=
ExecStart=/usr/bin/hbbs -k _ --mask 192.168.1.0/24
```

`/etc/systemd/system/rustdesk-hbbr.service.d/override.conf`

```ini
[Service]
ExecStart=
ExecStart=/usr/bin/hbbr -k _
```

ความหมายของออปชัน

- `-k _` = บังคับใช้คีย์ที่อยู่ใน `id_ed25519` (client ต้องใส่ public key ตรงกัน ไม่งั้นต่อไม่ติด)
- `--mask 192.168.1.0/24` = บอกว่า client จากวงนี้เป็น LAN → ต่อตรงได้ ไม่ต้องผ่าน relay
- **ไม่ตั้ง `-r`** เพราะ hbbs/hbbr อยู่เครื่องเดียวกัน client จะใช้ host เดียวกับ ID server เป็น relay เอง
  ถ้าย้าย relay ไปเครื่องอื่น หรือใช้โดเมน ให้ใส่ `-r <host>:21117` (คั่นหลายตัวด้วย comma ได้)

---

## 4. จัดการ service / อัปเดต

```bash
systemctl status rustdesk-hbbs rustdesk-hbbr
sudo systemctl restart rustdesk-hbbs rustdesk-hbbr
tail -f /var/log/rustdesk-server/hbbs.log /var/log/rustdesk-server/hbbr.log
ss -ltnup | grep -E '2111[4-9]'          # ตรวจว่าพอร์ต listen ครบ
```

อัปเดตเวอร์ชัน: ดาวน์โหลด `.deb` ตัวใหม่แล้ว `sudo apt install -y ./rustdesk-server-*.deb` (drop-in ยังอยู่)

---

## 5. ตั้งค่าฝั่ง client

ตั้งใน RustDesk client (มือถือ/PC) ที่ช่อง **ID/Relay Server** (กด “ตั้งค่า → เครือข่าย” หรือไอคอน ⋮ → ID/Relay)

```
ID Server     : 192.168.1.57        (ถ้าออกนอกวงแล้วทำ port forward → ใส่ IP/โดเมนสาธารณะ)
Relay Server  : (เว้นว่างได้)
Key           : ls7Y+iY4TauJqHLeOjwx+wO5PiYKf0vsYf56rMtOPQk=
```

ทดสอบ: ติดตั้ง client ทั้งสองฝั่ง → ตั้งค่าข้างบน → ฝั่งที่ถูกควบคุมจะแสดง ID (9 หลัก)
แล้วอีกฝั่งกด “เชื่อมต่อด้วย ID” ใส่ ID + รหัสผ่าน

---

## 6. ใช้งานจากนอกวง (WAN)

เครื่องนี้อยู่ในวง LAN (192.168.1.57) ถ้าจะใช้จากอินเทอร์เน็ตต้อง **port forward ที่ router**:

| พอร์ต | โปรโตคอล | ใช้ทำอะไร |
| --- | --- | --- |
| 21115 | TCP | NAT type test |
| 21116 | **TCP + UDP** | ID ลงทะเบียน/heartbeat (สำคัญสุด) |
| 21117 | TCP | relay |
| 21118, 21119 | TCP | websocket (web client) |

- ufw บนเครื่องนี้: **inactive** (ยังไม่มีอะไรบล็อก) ถ้าเปิดใช้ภายหลังต้อง `sudo ufw allow 21115:21119/tcp` และ `sudo ufw allow 21116/udp`
- แนะนำตั้ง DDNS/โดเมนชี้มาที่บ้าน แล้วใส่โดเมนนั้นในช่อง ID Server (router เปลี่ยน IP น้อยลง)
- ถ้าไม่ทำ port forward จะใช้ได้เฉพาะในวง LAN เดียวกัน

> ⚠️ **ตรวจแล้ว 2026-09-23: ISP บ้านนี้ทำ NAT ซ้อน (CGNAT)** — WAN IP ของ router = `10.144.241.31/32`
> (gateway `10.144.240.1`) ส่วน public IP `58.10.42.147` เป็นของ ISP ที่ใช้ร่วมกัน
> ⇒ **ตั้ง port forward IPv4 ที่ router ไปก็ไม่ทำงาน** (ทดสอบจาก 3 โหนดนอกบ้านได้ `Connection timed out`)
> ทางเลือกที่มีจริง:
> 1. **Tailscale** (ติดตั้งบนเครื่องนี้แล้ว — ดู AGENTS.md) รีโมทผ่าน IP `100.x` ได้ทุกที่ ไม่ต้องพึ่ง router
> 2. ขอ **public IPv4** จาก ISP (บางแพ็กเกจ/มีค่าใช้จ่าย) แล้ว port forward ที่ตั้งไว้จะกลับมาใช้ได้
> 3. ใช้ **IPv6** (router ได้ PD `2001:fb1:15e:1c8f::/64`) + DDNS แบบ AAAA — ต้องเปิด IPv6 firewall/pinhole ที่ router และยังไม่ได้ทดสอบ inbound
> 4. ใช้ RustDesk กับเซิร์ฟเวอร์สาธารณะของ RustDesk แทนการ self-host (ไม่ต้อง port forward เลย แต่ traffic ผ่านเซิร์ฟเวอร์เขา)


---

## 7. แก้ปัญหา (Troubleshooting)

- **client ต่อไม่ติด / ค้างที่ “กำลังเชื่อมต่อ”**: ตรวจ `-k _` ว่าตั้งทั้ง hbbs+hbbr, คีย์ใน client ตรงกับ `id_ed25519.pub`, พอร์ตเปิด/forward ครบ, ดู `hbbs.log`
- **อยากเปลี่ยนคีย์**: `sudo systemctl stop rustdesk-hbbs` → ลบ `/var/lib/rustdesk-server/id_ed25519*` → `sudo systemctl start rustdesk-hbbs` (คีย์ใหม่ → client ต้องอัปเดตทุกตัว)
- **เห็นจอแต่ควบคุมไม่ได้ (Wayland)**: ฝั่งเครื่องที่ถูกควบคุมถ้าเป็น Wayland ต้องอนุญาตการแชร์จอผ่าน xdg-desktop-portal
  (เครื่องนี้ใช้ GNOME/Wayland ตั้งแต่ 2026-09-23 — ถ้าควบคุมไม่ได้จริงๆ ให้ใช้ `switch-desktop.sh gnome --dm lightdm --session ubuntu-xorg` หรือ RDP)
- **hbbs ไม่ขึ้น**: `systemctl status rustdesk-hbbs` + ดู `hbbs.error` (มักเป็นพอร์ตชนหรือสิทธิ์เขียน `/var/lib/rustdesk-server`)
