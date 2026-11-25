<div align="center">

  <img src="assets/logo_glassline.png" alt="Aetron Logo" width="140" />

  # ⚡ Aetron - Next-Gen Fitness & Exercise Application
  
  **Nền tảng theo dõi và phân tích luyện tập thể thao thông minh thế hệ mới, tích hợp Flutter & Supabase**

  [![Flutter](https://img.shields.io/badge/Flutter-3.x-02569B?style=for-the-badge&logo=flutter&logoColor=white)](https://flutter.dev)
  [![Dart](https://img.shields.io/badge/Dart-3.x-0175C2?style=for-the-badge&logo=dart&logoColor=white)](https://dart.dev)
  [![Supabase](https://img.shields.io/badge/Supabase-Cloud%20Backend-3ECF8E?style=for-the-badge&logo=supabase&logoColor=white)](https://supabase.com)
  [![Download APK](https://img.shields.io/badge/Android%20APK-Tải%20về%20(Google%20Drive)-34A853?style=for-the-badge&logo=google-drive&logoColor=white)](https://drive.google.com/drive/u/1/folders/18ez4C2HK8CwyL7eStFa6fUMWuSv1KDPp)
  [![iOS PWA](https://img.shields.io/badge/iOS%20PWA-Thêm%20vào%20MH%20Chính-FF6F00?style=for-the-badge&logo=apple&logoColor=white)]()

</div>

---

## 📲 Hướng dẫn Cài đặt & Trải nghiệm (User Installation Guide)

Ứng dụng **Aetron** đã được tối ưu hóa toàn diện cho cả thiết bị di động (iOS, Android) và nền tảng Web:

### 🍎 1. Dành cho người dùng iOS (iPhone / iPad - Thêm vào Màn hình chính)
Aetron hỗ trợ chuẩn Progressive Web App (PWA) cao cấp với icon HD, Splash screen và chế độ Standalone toàn màn hình (không thanh địa chỉ Safari, trải nghiệm mượt mà như app tải từ App Store):

1. Mở trình duyệt **Safari** trên iPhone hoặc iPad.
2. Truy cập vào địa chỉ Web App đã deploy của **Aetron**.
3. Nhấn vào nút **Chia sẻ (Share)** ở thanh công cụ phía dưới màn hình *(biểu tượng ô vuông có mũi tên hướng lên)*.
4. Cuộn xuống và chọn **"Thêm vào Màn hình chính"** (*Add to Home Screen*).
5. Nhấn **"Thêm"** (*Add*) ở góc trên bên phải.
6. 🎉 **Hoàn tất!** Icon ứng dụng **Aetron** sẽ xuất hiện ngay trên Màn hình chính. Nhấn vào icon để mở và sử dụng ứng dụng ở chế độ toàn màn hình Native.

---

### 🤖 2. Dành cho người dùng Android
Người dùng Android có thể lựa chọn 1 trong 2 cách trải nghiệm tiện lợi:

* **📥 Cách 1: Tải trực tiếp file APK qua Google Drive (Khuyên dùng)**
  - 🔗 **Link tải APK chính thức:** [**Tải file cài đặt Aetron APK (Google Drive)**](https://drive.google.com/drive/u/1/folders/18ez4C2HK8CwyL7eStFa6fUMWuSv1KDPp)
  - Tải file **`app-release.apk`** về điện thoại.
  - Nhấn mở file vừa tải và chọn **Cài đặt** *(cho phép cài đặt ứng dụng từ nguồn không xác định/trình duyệt nếu điện thoại yêu cầu)*.
  - Mở app và tận hưởng đầy đủ tính năng theo dõi GPS nền, cảm biến bước chân thời gian thực và đồng bộ dữ liệu.

* **🌐 Cách 2: Cài đặt PWA qua Google Chrome**
  - Mở **Google Chrome** trên điện thoại Android và truy cập đường link Web App.
  - Nhấn vào biểu tượng menu **3 chấm (⋮)** ở góc trên bên phải.
  - Chọn **"Cài đặt ứng dụng"** hoặc **"Thêm vào Màn hình chính"** (*Install app / Add to Home screen*).

---

### 💻 3. Dành cho máy tính (Desktop / Web Browser)
* Truy cập trực tiếp qua mọi trình duyệt hiện đại (Google Chrome, Microsoft Edge, Safari, Firefox, Brave) trên macOS, Windows hoặc Linux.

---

## 🌟 Tổng quan sản phẩm (Product Overview)

**Aetron** là ứng dụng di động & web app chuyên sâu phục vụ theo dõi lộ trình thể thao (*Chạy bộ, Đạp xe, Đi bộ*). Ứng dụng kết hợp **bộ lọc GPS chống nhiễu đa tầng**, **bộ phân loại môi trường thông minh (Trong nhà / Ngoài trời)**, **tính toán năng lượng tiêu hao chuẩn MET y khoa**, **chương trình chạy bộ có cấu trúc (Intervals, Tempo, LSD)** và **bảng thành tích vinh danh Trophy Wall**.

---

## 🔥 Tính năng nổi bật (Key Features)

### 1. 🏃 Realtime GPS & Công nghệ lọc đường đi thông minh
- **Lọc nhiễu độ chính xác cao:** Tự động loại bỏ rung lắc GPS (`<0.25m`), thuật toán làm mượt vận tốc trung bình và tự động tạm dừng khi đứng yên.
- **Phân loại môi trường (Indoor / Outdoor Classifier):** Tự động phát hiện khi chạy trong nhà (máy chạy bộ) và chuyển đổi sang cảm biến bước chân Pedometer/Gia tốc kế để tối ưu pin.
- **Bản đồ trực quan & Nén Polyline:** Hiển thị đường chạy thời gian thực và thuật toán nén Polyline giảm >90% dung lượng đồng bộ.

### 2. 🏆 Bảng thành tích (Trophy Wall) & Kỷ lục cá nhân (PRs)
- **Hệ thống huy hiệu tự động:** Tự động mở khóa các danh hiệu theo khoảng cách (5K, 10K, Half Marathon, Marathon), chuỗi ngày tập luyện (Streak) và cột mốc lịch sử.
- **Trophy Wall:** Khu vực vinh danh thành tích cá nhân với giao diện sang trọng.

### 3. 🧭 Chương trình chạy bộ có cấu trúc (Structured Running Programs)
- **Kế hoạch tập luyện bài bản:** Các bài tập Chạy nhẹ (Easy Run), Biến tốc (Intervals), Nhịp độ (Tempo), Phục hồi (Recovery) và Chạy dài (Long Run).
- **HUD Hướng dẫn trực tiếp:** Đếm ngược 3D, thanh tiến độ mục tiêu và thông báo vòng chạy (Live Lap HUD) trong suốt buổi tập.

### 4. 📸 Thẻ chia sẻ mạng xã hội (Social Workout Share Card)
- Tạo ngay ảnh tổng kết buổi tập với thống kê quãng đường, thời gian, pace, calo và bản đồ để chia sẻ lên Story / mạng xã hội.

### 5. 🔒 Kiến trúc Offline-First & Bảo mật Supabase
- **Lưu trữ cục bộ an toàn:** Sử dụng SQLite & Isar DB giúp ghi nhận bài tập mượt mà ngay cả khi không có mạng.
- **Đồng bộ đám mây:** Tự động đồng bộ lên Supabase Cloud khi có kết nối trở lại.
- **Đăng nhập Google OAuth & Email:** Hỗ trợ đăng nhập nhanh Google trên cả Mobile và Web PWA.

---

## 🛠️ Công nghệ phát triển (Technology Stack)

| Thành phần | Công nghệ / Thư viện |
| :--- | :--- |
| **Framework** | [Flutter 3.x](https://flutter.dev) (Dart 3.x) |
| **Quản lý State** | [Riverpod 2.x](https://riverpod.dev) với code generation |
| **Backend & Database** | [Supabase](https://supabase.com) (Auth, PostgreSQL DB, Storage, Edge Functions Deno) |
| **Cơ sở dữ liệu cục bộ** | SQLite (`sqflite`), Isar Database |
| **Bản đồ & Định vị** | `flutter_map`, `latlong2`, `geolocator`, `sensors_plus`, `pedometer` |
| **Biểu đồ & UI** | `fl_chart`, `table_calendar`, Aetron Design System (Glassmorphism & Dark Mode) |

---

## 📄 Bản quyền (License)

Dự án được phân phối theo giấy phép **MIT License**.

---

<div align="center">
  <sub>Được phát triển với ❤️ bởi <b>Nguyen Duc Bao (DB-Ducbao113)</b> 🚀</sub>
</div>
