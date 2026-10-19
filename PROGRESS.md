# Progress & Architecture Plan: Mini-Project 3 (Receipt OCR & Expense Tracker)

**Ngày cập nhật:** 12/10/2026  
**Dự án:** `project3-flutter` (Đại học CNTT & TT Việt - Hàn - VKU)  
**Trạng thái:** Tạm dừng theo yêu cầu người dùng, đã lưu trạng thái toàn diện.

---

## 1. Yêu cầu đề bài & Rubric 10 điểm (Slide 41)

| Thành phần | Yêu cầu kỹ thuật | Điểm |
| :--- | :--- | :--- |
| **On-Device OCR & Heuristics** | Chụp ảnh camera (`image_picker`), OCR offline on-device (`google_mlkit_text_recognition`), Regex trích xuất Total, Date, Merchant. | **3.5 pts** |
| **Custom Canvas Visualization** | 100% `CustomPainter`: Animated Donut Chart theo Category + Weekly Bar Chart theo ngày. | **2.5 pts** |
| **State Management & DB** | Quản lý trạng thái (`Provider`), lưu trữ SQLite cục bộ (`sqflite`), lưu trữ file ảnh offline. | **2.0 pts** |
| **UI/UX Polish** | Material 3, Dark/Light Mode, Responsive layout, Dialog/Screen xem lại & sửa thủ công. | **1.0 pt** |
| **Deliverables & Report** | File `app-release.apk` có chữ ký, video demo thiết bị thật, GitHub repo sạch, báo cáo PDF 2–4 trang. | **1.0 pt** |

---

## 2. Kiến trúc Offline-First Hybrid (Đồng thuận thiết kế)

```text
[Chụp biên lai] 
       │
       ├── [Có mạng] ──> Gemini Flash API (Structured JSON extraction & Cố vấn tài chính)
       └── [Mất mạng] ─> On-device ML Kit OCR + Dart Regex Engine (Fallback)
                                │
                                ▼
                     [Local SQLite DB (SSOT)]
                     (sync_status: pending | synced)
                                │
                    [Connectivity Monitor]
                                │
                       [Mạng phục hồi]
                                ▼
                         [Sync Queue] ──> Cloud API / Supabase
```

* **Offline-First:** Tất cả giao dịch ghi trực tiếp vào SQLite trên máy. Hoạt động bình thường khi bật chế độ Máy bay.
* **Sync Queue:** Giao dịch lưu lúc offline có cờ `sync_status = 'pending_sync'`, khi có mạng sẽ tự động đẩy lên server.
* **Dual OCR Engine:**
  * Offline: Dùng ML Kit + Regex Engine (bóc Tên cửa hàng, Ngày, Tổng tiền).
  * Online: Gửi ảnh sang Gemini API để bóc chi tiết món hàng + sinh ghi chú tài chính, cache kết quả vào SQLite.
* **Custom Canvas:** Donut Chart và Bar Chart tự vẽ thủ công bằng `CustomPainter`, không dùng thư viện ngoài.

---

## 3. Trạng thái môi trường & Hệ thống

* Thư mục dự án: `D:\2026WORK\CrossPlatform\project3-flutter`
* Java: Java 21 LTS đã cài đặt sẵn (`java 21.0.12.1`).
* Dart SDK: Đang được cài đặt qua winget (`Google.DartSDK 3.13.4`).
* Flutter SDK: Chưa có trong PATH. Bước tiếp theo khi quay lại sẽ cấu hình Flutter SDK (tải zip stable vào `D:\Tools\flutter` và add PATH).

---

## 4. Các bước tiếp theo khi quay lại làm việc

1. **Setup SDK & Scaffold:** Hoàn tất Flutter SDK trong PATH, chạy `flutter create .` tại `D:\2026WORK\CrossPlatform\project3-flutter`.
2. **Core Logic & Database:**
   * Cài đặt dependencies: `provider`, `sqflite`, `path_provider`, `google_mlkit_text_recognition`, `image_picker`, `connectivity_plus`, `intl`.
   * Viết `database_helper.dart` (SQLite schema hỗ trợ offline sync).
   * Viết `receipt_regex_parser.dart` (bóc tách Total, Date, Merchant) kèm unit test.
3. **UI & Custom Canvas:**
   * Xây dựng `DonutChartPainter` và `WeeklyBarChartPainter` bằng `CustomPainter`.
   * Màn hình Home, Scan & Review, Statistics Dashboard.
4. **Online Layer (Gemini & Sync):**
   * Tích hợp Gemini Flash client.
   * `SyncQueueService` tự động đồng bộ khi online.
5. **Đóng gói Deliverables:** Build release APK, chuẩn bị kịch bản demo và viết báo cáo PDF 2-4 trang.
