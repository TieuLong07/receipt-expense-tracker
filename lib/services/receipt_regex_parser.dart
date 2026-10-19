// ponytail: Heuristic receipt parser with line item extraction; add LLM-based structured vision extractor when complex foreign receipts are needed.

import '../models/receipt.dart';

class ParsedReceiptResult {
  final String merchant;
  final double amount;
  final double subtotal;
  final DateTime date;
  final String category;
  final List<ReceiptItem> items;
  final String rawText;

  const ParsedReceiptResult({
    required this.merchant,
    required this.amount,
    required this.subtotal,
    required this.date,
    required this.category,
    required this.items,
    required this.rawText,
  });
}

class ReceiptRegexParser {
  static final RegExp _tenderOrExcludeKeywordPattern = RegExp(
    r'(sđt|sdt|khách|khach|phone|tel|điểm|diem|tích\s*lũy|tich\s*luy|point|msch|nv:|cqt|mã\s*ptt|mã\s*cqt|mã\s*hđ|ma\s*hd|hình\s*thức\s*thanh\s*toán|hinh\s*thuc\s*thanh\s*toan|tiền\s*mặt|tien\s*mat|tiền\s*thối|tien\s*thoi|tiền\s*thừa|tien\s*thua|cash|change|voucher|thẻ\s*tín\s*dụng)',
    caseSensitive: false,
  );

  static final RegExp _datePattern = RegExp(
    r'(\b\d{1,2}[/\-\.]\d{1,2}[/\-\.]\d{2,4}\b)|(\b\d{4}[/\-\.]\d{1,2}[/\-\.]\d{1,2}\b)',
  );

  static final RegExp _headerNoisePattern = RegExp(
    r'^(hóa\s*đơn|hoa\s*don|phiếu\s*thanh\s*toán|phieu\s*thanh\s*toan|phiếu\s*tính\s*tiền|phieu\s*tinh\s*tien|receipt|invoice|bill|đơn\s*hàng|order|welcome|cảm\s*ơn|cam\s*on|hotline|mst|địa\s*chỉ|dia\s*chi|tel|phone|\d+)',
    caseSensitive: false,
  );

  /// Parse raw OCR text into structured receipt metadata and line items.
  static ParsedReceiptResult parse(String rawText) {
    final lines = rawText
        .split('\n')
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .toList();

    final merchant = _extractMerchant(lines);
    final items = _extractItems(lines);
    final date = _extractDate(lines, rawText);
    final category = _inferCategory(merchant, rawText);

    final amountData = _extractTotal(lines, rawText, items);

    return ParsedReceiptResult(
      merchant: merchant,
      amount: amountData.total,
      subtotal: amountData.subtotal,
      date: date,
      category: category,
      items: items,
      rawText: rawText,
    );
  }

  static String _extractMerchant(List<String> lines) {
    for (final line in lines.take(5)) {
      final clean = line.replaceAll(RegExp(r'[^\w\s\u00C0-\u1EF9]', unicode: true), '').trim();
      if (clean.length >= 3 && !_headerNoisePattern.hasMatch(clean)) {
        // Strip prefixes like "1 " or "CTY "
        return clean;
      }
    }
    return lines.isNotEmpty ? lines.first : 'VKU Merchant';
  }

  /// Extracts individual purchased line items.
  static List<ReceiptItem> _extractItems(List<String> lines) {
    final items = <ReceiptItem>[];
    final itemHeaderPattern = RegExp(
      r'^(winmart|highlands|circle\s*k|phiếu|phieu|hóa\s*đơn|hoa\s*don|msch|nv:|mã|ma\s|ngày|ngay|date|time|quầy|bàn|\d{1,2}[/\-\.]\d{1,2}[/\-\.]\d{2,4})',
      caseSensitive: false,
    );
    final itemFooterPattern = RegExp(
      r'^(tổng|tong|thanh\s*toán|thanh\s*toan|khấu\s*trừ|khau\s*tru|chiết\s*khấu|chiet\s*khau|tiền\s*cần|tien\s*can|hình\s*thức|hinh\s*thuc|sđt|sdt|khách|khach|điểm|diem|voucher|tiền\s*mặt|tien\s*mat|tiền\s*thối|tien\s*thoi|tiền\s*thừa|tien\s*thua|cảm\s*ơn|cam\s*on|quét\s*qr|hotline|mst|địa\s*chỉ|subtotal|total|cash|change)',
      caseSensitive: false,
    );

    int i = 0;
    while (i < lines.length) {
      final line = lines[i];

      // Skip non-item headers/footers
      if (itemHeaderPattern.hasMatch(line) || itemFooterPattern.hasMatch(line)) {
        i++;
        continue;
      }

      // Format A (Retail multi-line: Line 1 = Item Name, Line 2 = Qty x Price ... LineTotal)
      // e.g. "1 WMNK Cam vàng TQ"
      //      "0.346 x 59,000 -3,460 16,954"
      if (i + 1 < lines.length) {
        final nextLine = lines[i + 1];
        final qtyPriceMatch = RegExp(r'([\d\.,]+)\s*x\s*([\d\.,]+)', caseSensitive: false).firstMatch(nextLine);
        if (qtyPriceMatch != null) {
          final nums = _findNumbers(nextLine);
          if (nums.isNotEmpty) {
            final qtyStr = qtyPriceMatch.group(1)?.replaceAll(',', '.') ?? '1';
            final qty = double.tryParse(qtyStr) ?? 1.0;
            final unitPriceStr = qtyPriceMatch.group(2) ?? '0';
            final unitPrice = _findNumbers(unitPriceStr).isNotEmpty ? _findNumbers(unitPriceStr).first : 0.0;
            final lineTotal = nums.last; // Last figure is the final line item amount

            var name = line.replaceFirst(RegExp(r'^\d+[\s\.\-]+'), '').trim();
            if (name.isNotEmpty && lineTotal > 0) {
              items.add(ReceiptItem(
                name: name,
                quantity: qty,
                unitPrice: unitPrice > 0 ? unitPrice : (lineTotal / (qty > 0 ? qty : 1)),
                totalPrice: lineTotal,
              ));
              i += 2;
              continue;
            }
          }
        }
      }

      // Format B (Single line: Item Name followed by Price)
      // e.g. "1. Phin Sữa Đá (L)     39.000"
      // e.g. "Snack Oishi          12.000"
      final singleLineMatch = RegExp(r'^(.*?)\s+([\d\.,]{3,})\s*(?:đ|vnd|vnđ|\$)?$', caseSensitive: false).firstMatch(line);
      if (singleLineMatch != null) {
        final rawName = singleLineMatch.group(1)?.trim() ?? '';
        final rawAmt = singleLineMatch.group(2) ?? '';
        final parsedAmt = _findNumbers(rawAmt);

        if (parsedAmt.isNotEmpty && !itemFooterPattern.hasMatch(rawName) && !itemHeaderPattern.hasMatch(rawName)) {
          final amt = parsedAmt.last;
          if (amt >= 500 && amt < 50000000) {
            final cleanName = rawName.replaceFirst(RegExp(r'^\d+[\s\.\-]+'), '').trim();
            if (cleanName.length >= 2) {
              items.add(ReceiptItem(
                name: cleanName,
                quantity: 1.0,
                unitPrice: amt,
                totalPrice: amt,
              ));
              i++;
              continue;
            }
          }
        }
      }

      i++;
    }

    return items;
  }

  static ({double total, double subtotal}) _extractTotal(List<String> lines, String fullText, List<ReceiptItem> items) {
    final itemsSum = items.fold(0.0, (sum, it) => sum + it.totalPrice);

    double? netPayable;
    double? totalSubtotal;

    // Specific Net Payable regex (Tiền cần thanh toán / Cần thanh toán / Net Amount)
    final netPattern = RegExp(r'(tiền\s*cần\s*thanh\s*toán|tien\s*can\s*thanh\s*toan|cần\s*thanh\s*toán|can\s*thanh\s*toan|phải\s*thanh\s*toán|net\s*amount)', caseSensitive: false);
    // General Gross Total regex (Tổng tiền / Tổng cộng / Thành tiền / Thanh toán)
    final grossPattern = RegExp(r'(tổng\s*cộng|tong\s*cong|tổng\s*tiền|tong\s*tien|thành\s*tiền|thanh\s*tien|thanh\s*toán|thanh\s*toan|grand\s*total|\btotal\b)', caseSensitive: false);

    for (int i = 0; i < lines.length; i++) {
      final line = lines[i];

      // Skip lines with exclusions (SĐT, Điểm, Mã, Hình thức thanh toán...)
      if (_tenderOrExcludeKeywordPattern.hasMatch(line)) {
        continue;
      }

      // Check Net Payable
      if (netPattern.hasMatch(line)) {
        final nums = _findNumbers(line);
        if (nums.isNotEmpty) {
          netPayable = nums.last;
        } else if (i + 1 < lines.length && !_tenderOrExcludeKeywordPattern.hasMatch(lines[i + 1])) {
          final nextNums = _findNumbers(lines[i + 1]);
          if (nextNums.isNotEmpty) {
            netPayable = nextNums.last;
          }
        }
      } else if (grossPattern.hasMatch(line)) {
        // Check Gross Total
        final nums = _findNumbers(line);
        if (nums.isNotEmpty) {
          totalSubtotal = nums.last;
        } else if (i + 1 < lines.length && !_tenderOrExcludeKeywordPattern.hasMatch(lines[i + 1])) {
          final nextNums = _findNumbers(lines[i + 1]);
          if (nextNums.isNotEmpty) {
            totalSubtotal = nextNums.last;
          }
        }
      }
    }

    // Determine final total
    final effectiveSubtotal = totalSubtotal ?? (itemsSum > 0 ? itemsSum : 0.0);
    // If netPayable is found and valid (e.g. 68,097), it represents actual out-of-pocket payment
    final effectiveTotal = netPayable ?? (effectiveSubtotal > 0 ? effectiveSubtotal : _fallbackFindTotal(fullText));

    return (total: effectiveTotal, subtotal: effectiveSubtotal > 0 ? effectiveSubtotal : effectiveTotal);
  }

  static double _fallbackFindTotal(String fullText) {
    final allNumbers = _findNumbers(fullText);
    if (allNumbers.isNotEmpty) {
      // Exclude values that look like years or small phone tails (< 1,000) or massive numbers (> 50,000,000)
      final validAmounts = allNumbers
          .where((n) => n >= 1000 && n < 50000000 && n != 2024 && n != 2025 && n != 2026)
          .toList();
      if (validAmounts.isNotEmpty) {
        validAmounts.sort();
        return validAmounts.last;
      }
      return allNumbers.last;
    }
    return 0.0;
  }

  static List<double> _findNumbers(String text) {
    final results = <double>[];
    // Matches formats: 125.000, 125,000, 125.000đ, 25.50, 468,097
    final numRegex = RegExp(r'\b(\d{1,3}(?:[.,]\d{3})*(?:[.,]\d{1,3})?|\d+)\s*(?:đ|vnd|vnđ|\$)?\b', caseSensitive: false);
    for (final match in numRegex.allMatches(text)) {
      var raw = match.group(1);
      if (raw == null) continue;

      // Remove trailing dot/comma
      raw = raw.replaceAll(RegExp(r'[.,]$'), '');

      // Determine separator logic (VND vs USD)
      if (raw.contains('.') && raw.contains(',')) {
        if (raw.lastIndexOf(',') > raw.lastIndexOf('.')) {
          // European/Vietnamese: 1.250,50 -> 1250.50
          raw = raw.replaceAll('.', '').replaceAll(',', '.');
        } else {
          // Standard US: 1,250.50 -> 1250.50
          raw = raw.replaceAll(',', '');
        }
      } else if (raw.contains('.')) {
        final parts = raw.split('.');
        if (parts.last.length == 3) {
          raw = raw.replaceAll('.', '');
        }
      } else if (raw.contains(',')) {
        final parts = raw.split(',');
        if (parts.last.length == 3) {
          raw = raw.replaceAll(',', '');
        } else {
          raw = raw.replaceAll(',', '.');
        }
      }

      final val = double.tryParse(raw);
      if (val != null && val > 0) {
        results.add(val);
      }
    }
    return results;
  }

  static DateTime _extractDate(List<String> lines, String fullText) {
    // 1. Prioritize lines that contain 'ngày', 'date', 'thời gian', or ISO/VN timestamps
    final datePrefixPattern = RegExp(r'(ngày|ngay|date|thời\s*gian|thoi\s*gian)', caseSensitive: false);
    for (final line in lines) {
      if (datePrefixPattern.hasMatch(line) || line.contains('/') || line.contains('-')) {
        final match = _datePattern.firstMatch(line);
        if (match != null) {
          final dt = _parseDateString(match.group(0)!);
          if (dt != null) return dt;
        }
      }
    }

    // 2. Scan entire text
    final match = _datePattern.firstMatch(fullText);
    if (match != null) {
      final dt = _parseDateString(match.group(0)!);
      if (dt != null) return dt;
    }

    return DateTime.now();
  }

  static DateTime? _parseDateString(String str) {
    final parts = str.split(RegExp(r'[/\-\.]'));
    if (parts.length == 3) {
      try {
        if (parts[0].length == 4) {
          // YYYY-MM-DD
          final y = int.parse(parts[0]);
          final m = int.parse(parts[1]);
          final d = int.parse(parts[2]);
          if (m >= 1 && m <= 12 && d >= 1 && d <= 31) {
            return DateTime(y, m, d);
          }
        } else {
          // DD-MM-YYYY
          var y = int.parse(parts[2]);
          if (y < 100) y += 2000;
          final m = int.parse(parts[1]);
          final d = int.parse(parts[0]);
          if (m >= 1 && m <= 12 && d >= 1 && d <= 31) {
            return DateTime(y, m, d);
          }
        }
      } catch (_) {}
    }
    return null;
  }

  static String _inferCategory(String merchant, String fullText) {
    final combined = '$merchant $fullText'.toLowerCase();
    if (RegExp(r'(cà phê|cafe|coffee|highlands|phúc long|starbucks|trà|tra sua|quán|cơm|phở|bún|bánh mì|căn tin|cantin|kfc|lotteria|pizza|bbq|nhà hàng|restaurant|food|ăn uống|món)').hasMatch(combined)) {
      return 'Food';
    }
    if (RegExp(r'(grab|be|gojek|taxi|xăng|petrolimex|gửi xe|vé xe|bus|xe buýt|transport)').hasMatch(combined)) {
      return 'Transport';
    }
    if (RegExp(r'(photo|photocopy|sách|nhà sách|fahasa|in ấn|vku|học phí|bút|vpp|văn phòng phẩm|tập|giấy)').hasMatch(combined)) {
      return 'Study';
    }
    if (RegExp(r'(coop|winmart|circle k|7-eleven|family mart|bách hóa|siêu thị|mart|market|quần áo|shopee|lazada|tiki|store|thịt|heo|bò|cam|thực phẩm)').hasMatch(combined)) {
      return 'Shopping';
    }
    if (RegExp(r'(cgv|lotte cinema|rạp phim|bida|game|karaoke|net|cinema|phim)').hasMatch(combined)) {
      return 'Entertainment';
    }
    return 'Other';
  }
}
