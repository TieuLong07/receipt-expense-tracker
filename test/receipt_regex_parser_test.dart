import 'package:flutter_test/flutter_test.dart';
import 'package:receipt_expense_tracker/services/receipt_regex_parser.dart';

void main() {
  group('ReceiptRegexParser Unit Tests', () {
    test('Parses WinMart receipt with item breakdown and discount correctly', () {
      const sample = '''
      WinMart
      MSCH: 1645 NV: 09020371
      PHIẾU TÍNH TIỀN
      06/03/2026 11:28|MSCH:1645|NV:09020371
      Mã PTT: 164503260301812
      Mã CQT: M1-26-CPN7O-03035601812
      1 WMNK Cam vàng TQ
      0.346 x 59,000 -3,460 16,954
      2 MEAT DELI [SIG] Thịt heo xay đặc biệt
      0.36 x 182,900 65,844
      3 MEAT DELI Thịt heo xay
      0.366 x 149,900 54,863
      4 MEAT DELI [PRE] Ba rọi rút sườn (S)
      0.42 x 287,900 120,918
      5 MEAT DELI [SIG] Nạc dăm đầu giòn
      0.318 x 301,900 96,004
      6 MEAT DELI [SIG] Nạc dăm đầu giòn
      0.376 x 301,900 113,514
      TỔNG TIỀN: 468,097
      Khấu trừ, ưu đãi khác: 400,000
      Tiền cần thanh toán: 68,097
      Hình thức thanh toán:
      SĐT Khách: ***850
      Điểm tích lũy: 9,866,800
      BF5C
      ''';

      final result = ReceiptRegexParser.parse(sample);
      expect(result.merchant, equals('WinMart'));
      // Net payable is 68,097 (never 850!)
      expect(result.amount, equals(68097.0));
      // Subtotal of goods is 468,097
      expect(result.subtotal, equals(468097.0));
      expect(result.date.day, equals(6));
      expect(result.date.month, equals(3));
      expect(result.date.year, equals(2026));
      expect(result.category, equals('Shopping'));

      // Check item breakdown
      expect(result.items.length, equals(6));
      expect(result.items[0].name, contains('Cam vàng'));
      expect(result.items[0].totalPrice, equals(16954.0));
      expect(result.items[1].name, contains('Thịt heo xay đặc biệt'));
      expect(result.items[1].totalPrice, equals(65844.0));
      expect(result.items[3].name, contains('Ba rọi rút sườn'));
      expect(result.items[3].totalPrice, equals(120918.0));
    });

    test('Parses Highlands Coffee receipt correctly', () {
      const sample = '''
      HÓA ĐƠN BÁN HÀNG
      HIGHLANDS COFFEE VKU
      Địa chỉ: Nam Kỳ Khởi Nghĩa, Đà Nẵng
      Ngày: 19/10/2026 09:30
      1. Phin Sữa Đá (L)     39.000
      2. Bánh Mì Thịt Nướng  29.000
      ------------------------------
      TỔNG CỘNG:            68.000 đ
      Tiền mặt:            100.000 đ
      Tiền thối:            32.000 đ
      Cảm ơn quý khách!
      ''';

      final result = ReceiptRegexParser.parse(sample);
      expect(result.merchant, contains('HIGHLANDS COFFEE'));
      expect(result.amount, equals(68000.0));
      expect(result.date.year, equals(2026));
      expect(result.date.month, equals(10));
      expect(result.date.day, equals(19));
      expect(result.category, equals('Food'));
      expect(result.items.length, equals(2));
      expect(result.items[0].name, contains('Phin Sữa Đá'));
      expect(result.items[0].totalPrice, equals(39000.0));
    });

    test('Parses Circle K receipt correctly', () {
      const sample = '''
      CIRCLE K VIETNAM
      BILL #88392
      Date: 15/09/2026
      Snack Oishi          12.000
      Aquafina 500ml        7.000
      THANH TOAN:          19,000 VND
      ''';

      final result = ReceiptRegexParser.parse(sample);
      expect(result.merchant, contains('CIRCLE K'));
      expect(result.amount, equals(19000.0));
      expect(result.category, equals('Shopping'));
      expect(result.items.length, equals(2));
    });

    test('Parses Photocopy VKU receipt with Study category', () {
      const sample = '''
      TIỆM PHOTO VKU CAMPUS
      12-10-2026
      In tài liệu Cross-Platform 150 trang 45.000
      TỔNG TIỀN: 45.000 VND
      ''';

      final result = ReceiptRegexParser.parse(sample);
      expect(result.amount, equals(45000.0));
      expect(result.category, equals('Study'));
      expect(result.date.day, equals(12));
      expect(result.date.month, equals(10));
    });
  });
}
