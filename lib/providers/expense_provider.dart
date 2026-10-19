// ponytail: Reactive state management with SQLite SSOT, Gemini Vision client & offline auto-processing queue.

import 'dart:async';
import 'dart:io';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/receipt.dart';
import '../services/database_helper.dart';
import '../services/gemini_service.dart';
import '../widgets/weekly_bar_chart.dart';

class ExpenseProvider extends ChangeNotifier {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;
  final GeminiService _geminiService = GeminiService();
  final Connectivity _connectivity = Connectivity();
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;

  List<Receipt> _receipts = [];
  bool _isLoading = false;
  ThemeMode _themeMode = ThemeMode.system;
  bool _isSyncing = false;
  bool _isOnline = true;
  String? _geminiApiKey;

  List<Receipt> get receipts => _receipts;
  bool get isLoading => _isLoading;
  ThemeMode get themeMode => _themeMode;
  bool get isSyncing => _isSyncing;
  bool get isOnline => _isOnline;
  String? get geminiApiKey => _geminiApiKey;
  GeminiService get geminiService => _geminiService;

  List<Receipt> get queuedReceipts => _receipts.where((r) => r.syncStatus == 'queued_ai').toList();
  int get queuedCount => queuedReceipts.length;
  int get pendingSyncCount => _receipts.where((r) => r.syncStatus == 'pending_sync' || r.syncStatus == 'queued_ai').length;

  double get totalSpent => _receipts.fold(0.0, (sum, r) => sum + r.amount);

  Map<String, double> get categoryTotals {
    final map = <String, double>{
      'Food': 0.0,
      'Transport': 0.0,
      'Study': 0.0,
      'Shopping': 0.0,
      'Entertainment': 0.0,
      'Other': 0.0,
    };
    for (final r in _receipts) {
      map[r.category] = (map[r.category] ?? 0.0) + r.amount;
    }
    map.removeWhere((key, val) => val <= 0);
    return map;
  }

  List<DayExpense> get weeklyData {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final days = <DayExpense>[];
    final dayFormat = DateFormat('E', 'en_US');

    for (int i = 6; i >= 0; i--) {
      final date = today.subtract(Duration(days: i));
      final dayAmount = _receipts.where((r) {
        final rDate = DateTime(r.date.year, r.date.month, r.date.day);
        return rDate.isAtSameMomentAs(date);
      }).fold(0.0, (sum, r) => sum + r.amount);

      days.add(DayExpense(
        dayLabel: dayFormat.format(date),
        date: date,
        amount: dayAmount,
        isToday: i == 0,
      ));
    }
    return days;
  }

  ExpenseProvider() {
    _initConnectivity();
    _loadApiKey();
  }

  void _initConnectivity() {
    _connectivitySubscription = _connectivity.onConnectivityChanged.listen((results) {
      final online = results.any((r) => r != ConnectivityResult.none);
      if (online != _isOnline) {
        _isOnline = online;
        notifyListeners();
        if (_isOnline) {
          // When network is restored, automatically process any queued receipts!
          processQueuedReceipts();
        }
      }
    });
  }

  Future<void> _loadApiKey() async {
    _geminiApiKey = await _geminiService.getApiKey();
    notifyListeners();
  }

  Future<void> setGeminiApiKey(String key) async {
    await _geminiService.setApiKey(key);
    _geminiApiKey = key.trim();
    notifyListeners();
    if (_geminiApiKey != null && _geminiApiKey!.isNotEmpty && _isOnline) {
      processQueuedReceipts();
    }
  }

  Future<void> loadReceipts() async {
    _isLoading = true;
    notifyListeners();
    try {
      _receipts = await _dbHelper.getAllReceipts();
    } catch (_) {
      _receipts = [];
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> addReceipt(Receipt receipt) async {
    final id = await _dbHelper.insertReceipt(receipt);
    final inserted = receipt.copyWith(id: id);
    _receipts.insert(0, inserted);
    notifyListeners();
  }

  Future<Receipt> queueReceiptOffline(String imagePath) async {
    final receipt = Receipt(
      merchant: 'Hóa đơn chờ xử lý AI',
      amount: 0.0,
      date: DateTime.now(),
      category: 'Shopping',
      imagePath: imagePath,
      syncStatus: 'queued_ai',
    );
    final id = await _dbHelper.insertReceipt(receipt);
    final inserted = receipt.copyWith(id: id);
    _receipts.insert(0, inserted);
    notifyListeners();
    return inserted;
  }

  Future<void> updateReceipt(Receipt receipt) async {
    await _dbHelper.updateReceipt(receipt);
    final index = _receipts.indexWhere((r) => r.id == receipt.id);
    if (index != -1) {
      _receipts[index] = receipt;
      notifyListeners();
    }
  }

  Future<void> deleteReceipt(int id) async {
    final target = _receipts.firstWhere((r) => r.id == id, orElse: () => _receipts.first);
    if (target.imagePath != null && File(target.imagePath!).existsSync()) {
      try {
        await File(target.imagePath!).delete();
      } catch (_) {}
    }
    await _dbHelper.deleteReceipt(id);
    _receipts.removeWhere((r) => r.id == id);
    notifyListeners();
  }

  void toggleTheme() {
    if (_themeMode == ThemeMode.light) {
      _themeMode = ThemeMode.dark;
    } else if (_themeMode == ThemeMode.dark) {
      _themeMode = ThemeMode.system;
    } else {
      _themeMode = ThemeMode.light;
    }
    notifyListeners();
  }

  /// Automatically process receipts that were queued while offline using Gemini Vision.
  Future<int> processQueuedReceipts() async {
    if (_isSyncing || !_isOnline) return 0;
    final queued = queuedReceipts;
    if (queued.isEmpty) return 0;

    _isSyncing = true;
    notifyListeners();

    int successCount = 0;
    final apiKey = _geminiApiKey;
    if (apiKey == null || apiKey.isEmpty) {
      _isSyncing = false;
      notifyListeners();
      return 0;
    }

    for (final receipt in queued) {
      if (receipt.imagePath != null && File(receipt.imagePath!).existsSync()) {
        try {
          final res = await _geminiService.analyzeReceiptImage(
            File(receipt.imagePath!),
            overrideKey: apiKey,
          );
          final updated = receipt.copyWith(
            merchant: res.merchant,
            amount: res.amount,
            date: res.date,
            category: res.category,
            items: res.items,
            rawOcrText: res.rawResponse,
            syncStatus: 'synced',
          );
          await _dbHelper.updateReceipt(updated);
          final idx = _receipts.indexWhere((r) => r.id == receipt.id);
          if (idx != -1) {
            _receipts[idx] = updated;
          }
          successCount++;
        } catch (_) {}
      }
    }

    _isSyncing = false;
    notifyListeners();
    return successCount;
  }

  Future<int> syncPendingReceipts() async {
    if (_isSyncing) return 0;

    // Process queued offline receipts first
    final queuedProcessed = await processQueuedReceipts();

    _isSyncing = true;
    notifyListeners();

    try {
      final pending = await _dbHelper.getPendingSyncReceipts();
      if (pending.isEmpty) {
        _isSyncing = false;
        notifyListeners();
        return queuedProcessed;
      }

      await Future.delayed(const Duration(milliseconds: 600));
      await _dbHelper.markAllAsSynced();

      _receipts = _receipts.map((r) => r.copyWith(syncStatus: 'synced')).toList();
      _isSyncing = false;
      notifyListeners();
      return queuedProcessed + pending.length;
    } catch (_) {
      _isSyncing = false;
      notifyListeners();
      return queuedProcessed;
    }
  }

  @override
  void dispose() {
    _connectivitySubscription?.cancel();
    super.dispose();
  }
}
