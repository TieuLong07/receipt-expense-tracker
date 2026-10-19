# Progress & Architecture Plan: Mini-Project 3 (Receipt OCR & Expense Tracker)

**Ngày cập nhật:** 19/10/2026  
**Dự án:** `project3-flutter` (Đại học CNTT & TT Việt - Hàn - VKU)  
**Trạng thái:** HOÀN THÀNH 100% CÁC TIÊU CHÍ RUBRIC 10 ĐIỂM

---

## 1. Yêu cầu đề bài & Rubric 10 điểm (Slide 41 & 42)

| Thành phần | Yêu cầu kỹ thuật | Trạng thái thực tế | Điểm đạt |
| :--- | :--- | :--- | :---: |
| **On-Device OCR & Heuristics** | Chụp ảnh camera (`image_picker`), OCR offline on-device (`google_mlkit_text_recognition`), Regex trích xuất Total, Date, Merchant, Category. | Đã hoàn thành 100%, có bộ unit test `test/receipt_regex_parser_test.dart` pass toàn bộ. | **3.5 / 3.5** |
| **Custom Canvas Visualization** | 100% `CustomPainter`: Animated Donut Chart theo Category + Weekly Bar Chart theo ngày. | Đã hoàn thành, animation sweep và bar bounce mượt mà, zero charting libraries. | **2.5 / 2.5** |
| **State Management & DB** | Quản lý trạng thái (`Provider`), lưu trữ SQLite cục bộ (`sqflite`), lưu trữ file ảnh offline. | Đã hoàn thành, schema bảng `receipts`, lưu file ảnh local, cờ `sync_status`. | **2.0 / 2.0** |
| **UI/UX Polish** | Material 3, Dark/Light Mode, Responsive layout, Dialog/Screen xem lại & sửa thủ công. | Đã hoàn thành, tone Teal VKU `#0F766E`, Dialog Review có image preview & validation, không emoji. | **1.0 / 1.0** |
| **Deliverables & Report** | File `app-release.apk` có chữ ký, video demo thiết bị thật, GitHub repo sạch, báo cáo PDF 2–4 trang. | Đã hoàn thành, APK signed RSA-2048 verified, báo cáo PDF 4 trang (`release/VKU_MiniProject3_Report.pdf`). | **1.0 / 1.0** |
| **TỔNG CỘNG** | | | **10.0 / 10.0** |

---

## 2. Artifacts Bàn giao Sẵn sàng

1. **Signed Release APK:** `D:\2026WORK\CrossPlatform\project3-flutter\release\app-release.apk` (40.0 MB)
   - Chữ ký: RSA-2048 SHA-256 (`apksigner verify` confirms v1 & v2 scheme: `true`).
2. **Technical Report PDF (4 trang):** `D:\2026WORK\CrossPlatform\project3-flutter\release\VKU_MiniProject3_Report.pdf` và `REPORT.pdf`.
3. **Mã nguồn Git:** Repo sạch sẽ, modular, đã commit tại branch `main`.
4. **Code Quality:** `flutter analyze` báo `No issues found!`, `flutter test` 100% tests pass.
