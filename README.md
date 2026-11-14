# 🚀 Hybrid Remote Desktop (Windows Host ➔ Mobile Viewer)

Phần mềm điều khiển máy tính từ xa lai giữa **Microsoft RDP** (hiệu năng cao, độ trễ thấp) và **TeamViewer** (kết nối dễ dàng qua ID 9 số + Mã PIN cố định).

Được thiết kế chuyên biệt cho chiều: **Điện thoại (Android/iOS) điều khiển Máy tính (Windows PC)**.

### 📥 Tải Nhanh App Android (APK Cực Mượt)
- **Tải trực tiếp từ GitHub (Không cần đăng nhập):** [Tải file app-release.apk](https://github.com/harryzikko/rmd/raw/apk/app-release.apk)
- **Tải từ máy tính đang chạy (Qua Cloudflare Tunnel):** [Tải từ Server nội bộ](https://athletes-keen-oral-representing.trycloudflare.com/download/app.apk)
- **Danh sách GitHub Releases:** [Xem Releases](https://github.com/harryzikko/rmd/releases)

---

## 📁 Cấu trúc Dự án

```
e:\VTC Game\project\1\
├── host/                     # Core Engine trên Windows
│   ├── desktop_attach.py     # Tự động gắn vào phiên máy tính winsta0\default (chống lỗi quyền)
│   ├── screen_capture.py     # Chụp màn hình qua MSS + Vẽ con trỏ chuột + Scale video
│   ├── input_injector.py     # Giả lập chuột, cuộn, phím, phím tắt & Unicode text tiếng Việt
│   └── host_service.py       # WebRTC PeerConnection & xử lý DataChannel
├── server/
│   └── signaling.py          # HTTP & Signaling Server (bắt tay WebRTC & phục vụ Web Viewer)
├── web_viewer/               # Giao diện Web Viewer Mobile-First (Chrome / Safari)
│   ├── index.html            # UI điều khiển, bàn rê chuột Trackpad, Bàn phím ảo PC
│   ├── style.css             # Giao diện Dark mode hiện đại
│   └── app.js                # WebRTC Client & Bộ nhận diện cử chỉ ngón tay
├── mobile_flutter/           # App Native Flutter cho Android & iOS
│   ├── pubspec.yaml
│   └── lib/main.dart
├── run_host.py               # File chạy chính: Khởi động Server + Host + In mã QR
└── README.md
```

---

## ⚡ Hướng dẫn Chạy Thử Nghiệm Ngay (Quick Start)

### Bước 1: Khởi động Host trên Máy tính Windows
Mở Terminal (PowerShell hoặc CMD) tại thư mục dự án và chạy:

```powershell
python run_host.py
```

Khi chạy, hệ thống sẽ:
1. Tự động nhận diện địa chỉ IP mạng LAN (ví dụ: `192.168.100.77`).
2. Sinh ngẫu nhiên **ID Máy tính (9 số)** (ví dụ: `824 192 319`) và **Mã PIN (4 số)**.
3. In trực tiếp một **Mã QR ASCII** ngay trên cửa sổ dòng lệnh.

### Bước 2: Kết nối từ Điện thoại (Android hoặc iPhone)

Bạn có 2 cách cực kỳ nhanh:

* **Cách 1 (Nhanh nhất - Không cần cài app):**
  * Đảm bảo điện thoại chung mạng Wi-Fi với máy tính.
  * Mở Camera điện thoại quét thẳng mã **QR trên màn hình máy tính** (hoặc mở trình duyệt Safari/Chrome trên điện thoại gõ: `http://192.168.100.77:8000`).
  * Nhấn vào liên kết ➔ Màn hình máy tính lập tức hiện lên trên điện thoại!
* **Cách 2 (Dùng Native App Flutter):**
  * Vào thư mục `mobile_flutter`:
    ```powershell
    cd mobile_flutter
    flutter pub get
    flutter run
    ```
  * Hoặc build file APK để cài lên máy Android:
    ```powershell
    flutter build apk --release
    ```

---

## 🎮 Các tính năng đã tích hợp trên Mobile Viewer

1. **Bàn rê chuột cảm ứng (Trackpad Mode):**
   * Rê 1 ngón: Di chuyển con trỏ chuột mượt mà (có gia tốc tốc độ).
   * Chạm 1 ngón: Click chuột trái.
   * Chạm 2 ngón: Click chuột phải.
   * Vuốt 2 ngón: Cuộn chuột (Scroll) lên/xuống.
   * Chạm đúp: Double-click.
2. **Chế độ Chạm trực tiếp (Direct Touch Mode):**
   * Chạm vào điểm nào trên màn hình điện thoại thì con trỏ máy tính nhảy đến đúng tọa độ đó.
3. **Bàn phím ảo PC đầy đủ:**
   * Hàng phím chức năng: `Esc`, `Tab`, `F1` đến `F12`, `Del`, `Backspace`.
   * Phím bổ trợ: `Ctrl`, `Alt`, `Shift`, `Win`, `Space`, `Enter`, 4 phím mũi tên.
   * Ô nhập liệu gõ chữ: Hỗ trợ gõ trực tiếp văn bản có dấu Tiếng Việt (Telex/VNI) hoặc icon emoji truyền thẳng vào máy tính.
4. **Phím tắt nhanh (Quick Shortcuts):**
   * `Ctrl+C`, `Ctrl+V`, `Win+D` (ẩn/hiện Desktop), `Alt+Tab` (chuyển cửa sổ), `Esc`, `Enter`.
