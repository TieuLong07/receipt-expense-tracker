// ponytail: Backend API Client connecting to the server-side LLM completion service.

import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/receipt.dart';
import 'receipt_regex_parser.dart';

class BackendApiService {
  static const String _prefServerUrl = 'backend_server_url';
  
  // Default server: Cloudflare 24/7 Serverless Worker
  static const String defaultServerUrl = 'https://receipt-expense-ai.nguyenhlong2203.workers.dev';

  Future<String> getServerUrl() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_prefServerUrl) ?? defaultServerUrl;
  }

  Future<void> setServerUrl(String url) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefServerUrl, url.trim());
  }

  /// Sends image to server-side LLM completion API and parses structured result.
  Future<ParsedReceiptResult> analyzeReceiptViaServer(File imageFile, {String? customUrl}) async {
    final baseUrl = customUrl ?? await getServerUrl();
    final cleanBase = baseUrl.endsWith('/') ? baseUrl.substring(0, baseUrl.length - 1) : baseUrl;
    final url = Uri.parse('$cleanBase/api/analyze-receipt');

    final bytes = await imageFile.readAsBytes();
    final base64Image = base64Encode(bytes);

    final response = await http.post(
      url,
      headers: {
        'Content-Type': 'application/json',
        'User-Agent': 'VKUExpenseTracker/1.0.0 (Android; Mobile)',
      },
      body: jsonEncode({
        'image_base64': base64Image,
        'mime_type': 'image/jpeg',
      }),
    ).timeout(const Duration(seconds: 15));

    if (response.statusCode != 200) {
      throw Exception('Server Error (${response.statusCode}): ${response.body}');
    }

    final json = jsonDecode(response.body);
    if (json['success'] != true || json['data'] == null) {
      throw Exception(json['error'] ?? 'Invalid response from backend server.');
    }

    final data = json['data'] as Map<String, dynamic>;
    final merchant = (data['merchant'] as String?)?.trim() ?? 'Unknown Merchant';
    final totalAmount = (data['total_amount'] as num?)?.toDouble() ?? 0.0;
    final subtotal = (data['subtotal'] as num?)?.toDouble() ?? totalAmount;
    final category = (data['category'] as String?) ?? 'Shopping';

    DateTime date = DateTime.now();
    final dateStr = data['date'] as String?;
    if (dateStr != null && dateStr.isNotEmpty) {
      date = DateTime.tryParse(dateStr) ?? DateTime.now();
    }

    final rawItems = data['items'] as List?;
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

    return ParsedReceiptResult(
      merchant: merchant,
      amount: totalAmount > 0 ? totalAmount : subtotal,
      subtotal: subtotal > 0 ? subtotal : totalAmount,
      date: date,
      category: category,
      items: items,
      rawText: jsonEncode(data),
    );
  }

  /// Check server health
  Future<bool> checkHealth({String? customUrl}) async {
    try {
      final baseUrl = customUrl ?? await getServerUrl();
      final cleanBase = baseUrl.endsWith('/') ? baseUrl.substring(0, baseUrl.length - 1) : baseUrl;
      final url = Uri.parse('$cleanBase/api/health');
      final res = await http.get(url, headers: {
        'User-Agent': 'VKUExpenseTracker/1.0.0 (Android; Mobile)',
      }).timeout(const Duration(seconds: 4));
      return res.statusCode == 200;
    } catch (_) {
      return false;
    }
  }
}
