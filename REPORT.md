# TECHNICAL REPORT: MINI-PROJECT 3
## On-Device OCR Receipt Expense Tracker (Flutter, ML Kit, Heuristic Engine, Local SQLite)

**Học phần:** Phát triển ứng dụng Đa nền tảng (Cross-Platform Mobile Development)  
**Trường:** Đại học Công nghệ Thông tin và Truyền thông Việt - Hàn (VKU)  
**Tác giả:** Nguyễn Hoàng Long (tieulong07)  
**Thời gian hoàn thành:** 19/10/2026  
**Artifact bàn giao:** `release/app-release.apk` (Signed Release APK)

---

## 1. Tổng quan & Bối cảnh Đồ án (Executive Summary)

Trong bối cảnh sinh viên và ban quản lý câu lạc bộ tại VKU thường xuyên phải xử lý các hóa đơn tiền mặt (căn tin, in ấn tài liệu, mua sắm vật tư sự kiện), việc ghi chép thủ công vào sổ sách hoặc Google Sheets rất tốn thời gian và dễ xảy ra sai sót.

Dự án **VKU Receipt Expense Tracker** được xây dựng trên nền tảng **Flutter 3.27**, giải quyết triệt để bài toán trên thông qua kiến trúc **Offline-First On-Device AI**:
1. **100% Offline Capability:** Quét biên lai, nhận diện chữ (OCR) và bóc tách thông tin hoàn toàn trên thiết bị mà không cần gửi ảnh lên cloud hay kết nối Internet.
2. **Local SQLite SSOT:** Lưu trữ toàn bộ lịch sử chi tiêu và ảnh hóa đơn vào bộ nhớ cục bộ an toàn.
3. **Data Visualization bằng Canvas thuần:** Tự vẽ biểu đồ Donut và Bar Chart bằng `CustomPainter` (không phụ thuộc bất kỳ thư viện biểu đồ bên ngoài nào).
4. **Hybrid Sync Queue:** Hỗ trợ đánh dấu trạng thái `pending_sync` khi offline và sẵn sàng đồng bộ lên cloud khi có kết nối mạng.

---

## 2. Kiến trúc Hệ thống & Luồng Dữ liệu (System Architecture)

```text
[ Physical Receipt ]
        │
        ▼
[ Camera / Gallery ] ── (image_picker)
        │
        ▼
[ Local Storage ] ───── (path_provider: /receipt_photos/*.jpg)
        │
        ▼
[ ML Kit On-Device ] ── (google_mlkit_text_recognition: Latin script)
        │
        ▼
[ Regex Heuristic ] ─── (ReceiptRegexParser: Total, Date, Merchant, Category)
        │
        ▼
[ Review & Edit ] ───── (ReviewReceiptDialog: Cho phép user kiểm tra/sửa thủ công)
        │
        ▼
[ SQLite DB (SSOT) ] ── (sqflite: receipts table with sync_status)
        │
        ▼
[ UI / Visualization ]─ (Provider State -> DonutChartPainter & WeeklyBarChartPainter)
```

---

## 3. Chi tiết Kỹ thuật theo Rubric 10 Điểm

### 3.1. On-Device OCR & Heuristics (3.5 Điểm)
* **ML Kit Text Recognition:** Sử dụng Google ML Kit bundled Latin model on-device. Tốc độ nhận diện trung bình ~300ms - 500ms trên CPU thiết bị di động, bảo mật 100% quyền riêng tư người dùng.
* **Heuristic Regex Parser Engine (`lib/services/receipt_regex_parser.dart`):**
  * **Trích xuất Tổng tiền (Total):**
    * Nhận diện các từ khóa: `TỔNG CỘNG`, `TỔNG TIỀN`, `THÀNH TIỀN`, `CẦN THANH TOÁN`, `TOTAL`, `GRAND TOTAL`, `AMOUNT DUE`.
    * Bộ lọc phân biệt thông minh: Tách biệt dòng tổng tiền với dòng tiền khách đưa / tiền thối (`TIỀN MẶT`, `CASH`, `CHANGE`, `TIỀN THỐI`).
    * Chuẩn hóa dấu phân cách hàng nghìn/thập phân: Xử lý linh hoạt format Việt Nam (`68.000 đ`, `125,000 VND`) lẫn quốc tế (`25.50`).
    * Thuật toán Fallback: Tìm số tiền hợp lệ có giá trị lớn nhất trong văn bản nếu không tìm thấy từ khóa trực tiếp.
  * **Trích xuất Ngày tháng (Date):**
    * Bóc tách các định dạng `DD/MM/YYYY`, `DD-MM-YYYY`, `YYYY-MM-DD`, `DD.MM.YY`.
    * Tự động gán ngày hiện tại (`DateTime.now()`) nếu hóa đơn bị mờ phần ngày.
  * **Trích xuất Tên cửa hàng (Merchant Header):**
    * Phân tích 5 dòng đầu tiên của hóa đơn, loại bỏ các dòng rác tiêu đề chung (`HÓA ĐƠN`, `PHIẾU THANH TOÁN`, `WELCOME`, mã số thuế, số điện thoại).
  * **Phân loại danh mục tự động (Category Guesser):**
    * Tự động ánh xạ vào 6 danh mục: `Food` (Highlands, trà sữa, cơm, canteen), `Transport` (Grab, xăng, xe buýt), `Study` (Photo, sách, Fahasa, VKU), `Shopping` (Circle K, siêu thị), `Entertainment` (CGV, rạp phim, bida), `Other`.
* **Automated Testing:** Bộ unit test tự động trong `test/receipt_regex_parser_test.dart` đạt 100% pass với các mẫu hóa đơn thực tế.

---

### 3.2. Custom Canvas Visualization (2.5 Điểm)
Toàn bộ phần trực quan hóa dữ liệu được vẽ thủ công bằng Flutter `Canvas` API (`CustomPainter`), hoàn toàn không sử dụng fl_chart hay charts_flutter.

1. **Animated Donut Category Chart (`lib/widgets/donut_chart.dart`):**
   * Sử dụng `Canvas.drawArc` với tọa độ tâm, bán kính động và stroke width 24dp.
   * Tạo khe hở thẩm mỹ (`gapAngle = 0.04 rad`) giữa các lát cắt danh mục.
   * Bảng màu Material 3 hài hòa (Emerald, Blue, Purple, Amber, Pink, Slate) tương ứng từng danh mục.
   * `AnimationController` (900ms, `Curves.easeOutCubic`) tạo hiệu ứng quét góc sweep mượt mà khi tải hoặc thay đổi dữ liệu.
   * Hiển thị tổng số tiền chi tiêu ở trung tâm vòng tròn kèm subtitle rõ ràng.
   * Bảng chú giải (Legend) dạng pill bo tròn hiển thị phần trăm chi tiêu.

2. **Weekly Bar Chart (`lib/widgets/weekly_bar_chart.dart`):**
   * Sử dụng `Canvas.drawRRect` để tạo các cột bo tròn góc mềm mại (`Radius.circular(6)`).
   * Tự động tính toán thang đo (scaling ratio) với 15% headroom để cột không bị chạm viền trên.
   * Đường kẻ lưới mờ (grid guides) tại 0%, 50%, 100% và baseline rõ ràng.
   * Highlight ngày hiện tại và ngày có mức chi tiêu cao nhất với màu nhấn (Accent Primary).
   * Hiển thị nhãn số tiền compact (ví dụ: `45k`, `120k`) ngay trên đỉnh mỗi cột khi animation hoàn thành > 80%.

---

### 3.3. State Management & SQLite Database (2.0 Điểm)
* **Kiến trúc State Management:** Sử dụng `Provider` (`ChangeNotifier`) quản lý luồng dữ liệu một chiều (Unidirectional Data Flow) tinh gọn, tách bạch Business Logic khỏi UI Widgets.
* **Cơ sở dữ liệu SQLite (`lib/services/database_helper.dart`):**
  * Tích hợp `sqflite` với schema bảng `receipts`:
    * `id`: Khóa chính tự tăng (Primary Key Autoincrement).
    * `merchant`, `amount`, `date`, `category`: Metadata chi tiêu.
    * `image_path`: Đường dẫn file ảnh hóa đơn lưu offline trong Document Directory.
    * `raw_ocr_text`: Toàn văn OCR phục vụ kiểm tra lại.
    * `sync_status`: Cờ đồng bộ (`pending_sync` hoặc `synced`).
  * Đầy đủ thao tác CRUD: Thêm mới, đọc danh sách, cập nhật thông tin sau khi sửa, xóa bản ghi (kèm dọn dẹp file ảnh vật lý).
* **Sync Queue:** Các bản ghi tạo mới được gán mặc định `pending_sync`. Nút Sync trên AppBar kích hoạt tiến trình mô phỏng đồng bộ cloud và tự động cập nhật cờ thành `synced`.

---

### 3.4. UI/UX Polish (1.0 Điểm)
* **Chuẩn Material 3:** Sử dụng `ColorScheme.fromSeed` với tone màu chủ đạo Teal VKU (`#0F766E`), card viền phẳng (flat outline) hiện đại.
* **Dark / Light Mode:** Nút chuyển đổi ThemeMode trực tiếp trên AppBar, hỗ trợ đầy đủ độ tương phản màu sắc trên cả 2 giao diện.
* **Review & Manual Correction Dialog (`lib/widgets/review_receipt_dialog.dart`):**
  * Hiển thị ngay sau khi OCR hoàn tất hoặc khi người dùng nhấp vào một giao dịch trong danh sách.
  * Cho phép người dùng xem lại ảnh gốc, chỉnh sửa tên quán, sửa số tiền (hỗ trợ nhập số linh hoạt), chọn lại ngày qua DatePicker và thay đổi danh mục trước khi lưu vào database.
* **Quy chuẩn UX sạch:** Không dùng emoji trong giao diện; sử dụng hệ thống Material Icons sắc nét, có trạng thái trực quan khi đang xử lý OCR (Modal HUD overlay).

---

### 3.5. Deliverables & Packaging (1.0 Điểm)
* **Signed Release APK:**
  * Khóa ký: Khóa RSA 2048-bit, thuật toán `SHA256withRSA`, thời hạn 10,000 ngày.
  * Cấu hình ProGuard / R8 (`proguard-rules.pro`): Tối ưu hóa kích thước APK và giữ các symbol cần thiết cho ML Kit.
  * Kết quả kiểm tra bằng `apksigner`:
    * `Verifies: true`
    * `Verified using v1 scheme (JAR signing): true`
    * `Verified using v2 scheme (APK Signature Scheme v2): true`
  * File APK đã sẵn sàng cài đặt tại: `release/app-release.apk` (40.0 MB).
* **Source Code Cleanliness:** Repository Git sạch sẽ, mã nguồn modular, tuân thủ `flutter_lints`.

---

## 4. Kịch bản Video Demo & Hướng dẫn Chạy (Testing Script)

1. **Khởi động ứng dụng:**
   * Mở app, hiển thị Dashboard tổng quan (Tổng tiền: 0đ, biểu đồ trống, thông báo chưa có dữ liệu).
2. **Kịch bản Quét Hóa đơn (Offline OCR):**
   * Bật chế độ Máy bay (Airplane Mode).
   * Nhấn nút Floating Action Button `Scan Receipt` -> Chọn Camera hoặc Gallery.
   * Chọn ảnh hóa đơn Highlands Coffee hoặc Circle K.
   * Quan sát HUD xử lý on-device ML Kit (~400ms).
   * Hộp thoại **Verify Extracted Receipt** xuất hiện với thông tin tự động điền (Tên quán, Số tiền, Ngày, Danh mục Food/Shopping).
   * Người dùng chỉnh sửa nếu muốn -> Bấm `Confirm & Save`.
3. **Quan sát Biểu đồ Custom Canvas:**
   * Donut Chart tự động phân bổ tỷ lệ phần trăm theo danh mục với animation quét mượt mà.
   * Chuyển tab sang Weekly Trend: Bar Chart thể hiện mức chi tiêu theo ngày.
4. **Kiểm tra Offline Sync Queue:**
   * Quan sát badge `1 pending` màu cam trên AppBar.
   * Bấm nút Sync: App mô phỏng đẩy dữ liệu lên server và chuyển badge thành `Synced` màu xanh.
5. **Đổi Theme:** Bấm icon Mặt trời/Mặt trăng để kiểm tra độ tương thích Dark Mode.
