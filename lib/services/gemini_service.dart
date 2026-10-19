// ponytail: Gemini Flash Multimodal Vision Client; add streaming or Gemini 2.0 Pro when processing multi-page PDF invoices.

import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/receipt.dart';

class GeminiReceiptResult {
  final String merchant;
  final double amount;
  final double subtotal;
  final double discount;
  final DateTime date;
  final String category;
  final List<ReceiptItem> items;
  final String rawResponse;

  const GeminiReceiptResult({
    required this.merchant,
    required this.amount,
    required this.subtotal,
    this.discount = 0.0,
    required this.date,
    required this.category,
    required this.items,
    required this.rawResponse,
  });
}

class GeminiService {
  static const String _prefApiKey = 'gemini_api_key';
  static const String _prefCustomBaseUrl = 'gemini_base_url';

  // Default fallback API key from environment if available or user configurable
  static const String defaultModel = 'gemini-1.5-flash';

  Future<String?> getApiKey() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_prefApiKey);
  }

  Future<void> setApiKey(String key) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefApiKey, key.trim());
  }

  Future<String?> getCustomBaseUrl() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_prefCustomBaseUrl);
  }

  Future<void> setCustomBaseUrl(String url) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefCustomBaseUrl, url.trim());
  }

  /// Analyze a receipt image with Gemini Vision to extract 100% accurate structured JSON.
  Future<GeminiReceiptResult> analyzeReceiptImage(File imageFile, {String? overrideKey}) async {
    final apiKey = overrideKey ?? await getApiKey();
    if (apiKey == null || apiKey.isEmpty) {
      throw Exception('Missing Gemini API Key. Please configure your API key in Settings.');
    }

    final bytes = await imageFile.readAsBytes();
    final base64Image = base64Encode(bytes);

    final url = Uri.parse(
      'https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash:generateContent?key=$apiKey',
    );

    const prompt = '''
Bạn là chuyên gia phân tích và bóc tách hóa đơn thanh toán bán lẻ tại Việt Nam.
Hãy đọc thật kỹ ảnh hóa đơn này (tên cửa hàng, ngày giờ, từng dòng sản phẩm bao gồm khối lượng/số lượng, đơn giá, chiết khấu, và tổng tiền thanh toán).

Yêu cầu xuất ra DUY NHẤT một JSON hợp lệ (không kèm bất kỳ văn bản giải thích nào) theo cấu trúc:
{
  "merchant": "Tên thương hiệu hoặc cửa hàng (VD: WinMart, Highlands Coffee, Circle K...)",
  "date": "YYYY-MM-DD",
  "total_amount": số tiền thực tế khách cần thanh toán hoặc đã thanh toán (số thực, không chứa dấu phẩy/chấm),
  "subtotal": tổng tiền hàng trước giảm giá/khấu trừ (số thực),
  "discount": số tiền giảm giá, khuyến mãi hoặc voucher nếu có (số thực, mặc định 0),
  "category": "Food" | "Transport" | "Study" | "Shopping" | "Entertainment" | "Other",
  "items": [
    {
      "name": "Tên đầy đủ của sản phẩm/món hàng",
      "quantity": số lượng hoặc khối lượng kg (số thực, VD: 1, 0.35),
      "unit_price": đơn giá (số thực),
      "total_price": thành tiền của món hàng sau khi tính số lượng (số thực)
    }
  ]
}
Lưu ý quan trọng:
1. 'total_amount' là con số THỰC TẾ CHI TRẢ (Tiền cần thanh toán / Tổng thanh toán). Tuyệt đối KHÔNG lấy số điện thoại khách hàng, mã cửa hàng, số điểm tích lũy hoặc số tiền thối/tiền mặt khách đưa.
2. Trích xuất đầy đủ tất cả các món hàng trong danh sách hàng hóa.
''';

    final body = jsonEncode({
      'contents': [
        {
          'parts': [
            {'text': prompt},
            {
              'inline_data': {
                'mime_type': 'image/jpeg',
                'data': base64Image,
              }
            }
          ]
        }
      ],
      'generationConfig': {
        'response_mime_type': 'application/json',
        'temperature': 0.1,
      }
    });

    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: body,
    ).timeout(const Duration(seconds: 25));

    if (response.statusCode != 200) {
      throw Exception('Gemini API Error (${response.statusCode}): ${response.body}');
    }

    final data = jsonDecode(response.body);
    final candidates = data['candidates'] as List?;
    if (candidates == null || candidates.isEmpty) {
      throw Exception('No response candidates received from Gemini.');
    }

    final contentPart = candidates[0]['content']?['parts']?[0]?['text'] as String?;
    if (contentPart == null || contentPart.isEmpty) {
      throw Exception('Empty text content received from Gemini.');
    }

    final cleanJson = contentPart.trim().replaceFirst(RegExp(r'^```json\s*'), '').replaceFirst(RegExp(r'\s*```$'), '');
    final parsedMap = jsonDecode(cleanJson) as Map<String, dynamic>;

    final merchant = (parsedMap['merchant'] as String?)?.trim() ?? 'Unknown Merchant';
    final totalAmount = (parsedMap['total_amount'] as num?)?.toDouble() ?? 0.0;
    final subtotal = (parsedMap['subtotal'] as num?)?.toDouble() ?? totalAmount;
    final discount = (parsedMap['discount'] as num?)?.toDouble() ?? 0.0;
    final category = (parsedMap['category'] as String?) ?? 'Shopping';

    DateTime date = DateTime.now();
    final dateStr = parsedMap['date'] as String?;
    if (dateStr != null && dateStr.isNotEmpty) {
      date = DateTime.tryParse(dateStr) ?? DateTime.now();
    }

    final rawItems = parsedMap['items'] as List?;
    final items = <ReceiptItem>[];
    if (rawItems != null) {
      for (final it in rawItems) {
        if (it is Map<String, dynamic>) {
          items.add(ReceiptItem(
            name: (it['name'] as String?)?.trim() ?? 'Món hàng',
            quantity: (it['quantity'] as num?)?.toDouble() ?? 1.0,
            unitPrice: (it['unit_price'] as num?)?.toDouble() ?? 0.0,
            totalPrice: (it['total_price'] as num?)?.toDouble() ?? 0.0,
          ));
        }
      }
    }

    return GeminiReceiptResult(
      merchant: merchant,
      amount: totalAmount > 0 ? totalAmount : subtotal,
      subtotal: subtotal > 0 ? subtotal : totalAmount,
      discount: discount,
      date: date,
      category: category,
      items: items,
      rawResponse: contentPart,
    );
  }
}
