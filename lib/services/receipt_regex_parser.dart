// ponytail: Regex heuristics for receipt OCR; add LLM-based structured vision extractor when complex multi-language receipts are needed.

class ParsedReceiptResult {
  final String merchant;
  final double amount;
  final DateTime date;
  final String category;
  final String rawText;

  const ParsedReceiptResult({
    required this.merchant,
    required this.amount,
    required this.date,
    required this.category,
    required this.rawText,
  });
}

class ReceiptRegexParser {
  static final RegExp _totalKeywordPattern = RegExp(
    r'(tổng\s*cộng|tong\s*cong|tổng\s*tiền|tong\s*tien|thành\s*tiền|thanh\s*tien|cần\s*thanh\s*toán|can\s*thanh\s*toan|thanh\s*toán|thanh\s*toan|grand\s*total|net\s*amount|amount\s*due|\btotal\b)',
    caseSensitive: false,
  );

  static final RegExp _tenderKeywordPattern = RegExp(
    r'(tiền\s*mặt|tien\s*mat|tiền\s*thối|tien\s*thoi|tiền\s*thừa|tien\s*thua|cash|change)',
    caseSensitive: false,
  );

  static final RegExp _datePattern = RegExp(
    r'(\b\d{1,2}[/\-\.]\d{1,2}[/\-\.]\d{2,4}\b)|(\b\d{4}[/\-\.]\d{1,2}[/\-\.]\d{1,2}\b)',
  );

  static final RegExp _headerNoisePattern = RegExp(
    r'^(hóa\s*đơn|hoa\s*don|phiếu\s*thanh\s*toán|phieu\s*thanh\s*toan|phiếu\s*tính\s*tiền|receipt|invoice|bill|đơn\s*hàng|order|welcome|cảm\s*ơn|cam\s*on|hotline|mst|địa\s*chỉ|dia\s*chi|tel|phone|\d+)',
    caseSensitive: false,
  );

  /// Parse raw OCR text into structured fields.
  static ParsedReceiptResult parse(String rawText) {
    final lines = rawText
        .split('\n')
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .toList();

    final merchant = _extractMerchant(lines);
    final amount = _extractTotal(lines, rawText);
    final date = _extractDate(rawText);
    final category = _inferCategory(merchant, rawText);

    return ParsedReceiptResult(
      merchant: merchant,
      amount: amount,
      date: date,
      category: category,
      rawText: rawText,
    );
  }

  static String _extractMerchant(List<String> lines) {
    for (final line in lines.take(5)) {
      final clean = line.replaceAll(RegExp(r'[^\w\s\u00C0-\u1EF9]', unicode: true), '').trim();
      if (clean.length >= 3 && !_headerNoisePattern.hasMatch(clean)) {
        return clean;
      }
    }
    return lines.isNotEmpty ? lines.first : 'VKU Merchant';
  }

  static double _extractTotal(List<String> lines, String fullText) {
    // 1. Try finding lines with total keywords (excluding tender/cash lines)
    for (int i = 0; i < lines.length; i++) {
      final line = lines[i];
      if (_totalKeywordPattern.hasMatch(line) && !_tenderKeywordPattern.hasMatch(line)) {
        // Look in this line first
        final parsed = _findNumbers(line);
        if (parsed.isNotEmpty) {
          return parsed.last;
        }
        // If not in this line, check the immediate next line
        if (i + 1 < lines.length) {
          final nextParsed = _findNumbers(lines[i + 1]);
          if (nextParsed.isNotEmpty) {
            return nextParsed.last;
          }
        }
      }
    }

    // 2. Fallback: Find the largest reasonable amount across all lines (excluding tender lines)
    final allNumbers = _findNumbers(fullText);
    if (allNumbers.isNotEmpty) {
      // Filter out typical phone numbers / tax IDs (> 100,000,000 or year 2024..2030)
      final validAmounts = allNumbers.where((n) => n > 500 && n < 100000000 && n != 2024 && n != 2025 && n != 2026).toList();
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
    // Matches formats: 125.000, 125,000, 125.000đ, 25.50
    final numRegex = RegExp(r'\b(\d{1,3}(?:[.,]\d{3})*(?:[.,]\d{1,2})?|\d+)\s*(?:đ|vnd|vnđ|\$)?\b', caseSensitive: false);
    for (final match in numRegex.allMatches(text)) {
      var raw = match.group(1);
      if (raw == null) continue;
      
      // Remove trailing dot/comma
      raw = raw.replaceAll(RegExp(r'[.,]$'), '');
      
      // Determine separator logic (VND vs USD)
      if (raw.contains('.') && raw.contains(',')) {
        // e.g. 1,250.50 or 1.250,50
        if (raw.lastIndexOf(',') > raw.lastIndexOf('.')) {
          // European/Vietnamese: 1.250,50 -> 1250.50
          raw = raw.replaceAll('.', '').replaceAll(',', '.');
        } else {
          // Standard US: 1,250.50 -> 1250.50
          raw = raw.replaceAll(',', '');
        }
      } else if (raw.contains('.')) {
        // Could be 50.000 (thousand) or 25.50 (decimal)
        final parts = raw.split('.');
        if (parts.last.length == 3) {
          // 50.000 -> 50000
          raw = raw.replaceAll('.', '');
        }
      } else if (raw.contains(',')) {
        // Could be 50,000 (thousand) or 25,50 (decimal)
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

  static DateTime _extractDate(String text) {
    final match = _datePattern.firstMatch(text);
    if (match != null) {
      final str = match.group(0)!;
      final parts = str.split(RegExp(r'[/\-\.]'));
      if (parts.length == 3) {
        try {
          if (parts[0].length == 4) {
            // YYYY-MM-DD
            return DateTime(int.parse(parts[0]), int.parse(parts[1]), int.parse(parts[2]));
          } else {
            // DD-MM-YYYY
            var year = int.parse(parts[2]);
            if (year < 100) year += 2000;
            return DateTime(year, int.parse(parts[1]), int.parse(parts[0]));
          }
        } catch (_) {}
      }
    }
    return DateTime.now();
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
    if (RegExp(r'(coop|winmart|circle k|7-eleven|family mart|bách hóa|siêu thị|mart|market|quần áo|shopee|lazada|tiki|store)').hasMatch(combined)) {
      return 'Shopping';
    }
    if (RegExp(r'(cgv|lotte cinema|rạp phim|bida|game|karaoke|net|cinema|phim)').hasMatch(combined)) {
      return 'Entertainment';
    }
    return 'Other';
  }
}
