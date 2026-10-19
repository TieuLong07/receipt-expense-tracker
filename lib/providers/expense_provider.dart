// ponytail: Provider state management with SQLite CRUD and sync queue; add WebSockets when live multi-user club balance is required.

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/receipt.dart';
import '../services/database_helper.dart';
import '../widgets/weekly_bar_chart.dart';

class ExpenseProvider extends ChangeNotifier {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;

  List<Receipt> _receipts = [];
  bool _isLoading = false;
  ThemeMode _themeMode = ThemeMode.system;
  bool _isSyncing = false;

  List<Receipt> get receipts => _receipts;
  bool get isLoading => _isLoading;
  ThemeMode get themeMode => _themeMode;
  bool get isSyncing => _isSyncing;

  double get totalSpent => _receipts.fold(0.0, (sum, r) => sum + r.amount);

  int get pendingSyncCount => _receipts.where((r) => r.syncStatus == 'pending_sync').length;

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
    // Remove zero-spending categories to keep chart clean
    map.removeWhere((key, val) => val <= 0);
    return map;
  }

  List<DayExpense> get weeklyData {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final days = <DayExpense>[];
    final dayFormat = DateFormat('E', 'en_US'); // Mon, Tue, etc.

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

  Future<void> loadReceipts() async {
    _isLoading = true;
    notifyListeners();
    try {
      _receipts = await _dbHelper.getAllReceipts();
    } catch (_) {
      // In web or mock fallback
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

  Future<int> syncPendingReceipts() async {
    if (_isSyncing) return 0;
    _isSyncing = true;
    notifyListeners();

    try {
      final pending = await _dbHelper.getPendingSyncReceipts();
      if (pending.isEmpty) {
        _isSyncing = false;
        notifyListeners();
        return 0;
      }

      // Simulate network request to cloud backend (or Gemini parsing sync)
      await Future.delayed(const Duration(milliseconds: 1200));
      await _dbHelper.markAllAsSynced();

      // Update in-memory records
      _receipts = _receipts.map((r) => r.copyWith(syncStatus: 'synced')).toList();
      _isSyncing = false;
      notifyListeners();
      return pending.length;
    } catch (_) {
      _isSyncing = false;
      notifyListeners();
      return 0;
    }
  }
}
