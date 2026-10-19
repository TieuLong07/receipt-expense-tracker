import 'package:flutter_test/flutter_test.dart';
import 'package:receipt_expense_tracker/services/receipt_regex_parser.dart';

void main() {
  group('ReceiptRegexParser Unit Tests', () {
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
    });

    test('Parses Photocopy VKU receipt with Study category', () {
      const sample = '''
      TIỆM PHOTO VKU CAMPUS
      12-10-2026
      In tài liệu Cross-Platform 150 trang
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
