// ponytail: Material 3 Home & Scanning screen; add infinite scroll pagination when records exceed 1,000 receipts.

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/receipt.dart';
import '../providers/expense_provider.dart';
import '../services/ocr_service.dart';
import '../widgets/donut_chart.dart';
import '../widgets/review_receipt_dialog.dart';
import '../widgets/weekly_bar_chart.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with SingleTickerProviderStateMixin {
  final ImagePicker _picker = ImagePicker();
  final OcrService _ocrService = OcrService();
  late TabController _chartTabController;
  bool _isProcessingOcr = false;

  @override
  void initState() {
    super.initState();
    _chartTabController = TabController(length: 2, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ExpenseProvider>().loadReceipts();
    });
  }

  @override
  void dispose() {
    _chartTabController.dispose();
    _ocrService.dispose();
    super.dispose();
  }

  Future<void> _handleImageCapture(ImageSource source) async {
    try {
      final pickedFile = await _picker.pickImage(
        source: source,
        imageQuality: 90,
      );
      if (pickedFile == null) return;

      setState(() => _isProcessingOcr = true);

      // Save photo locally for persistence
      final savedImagePath = await _ocrService.saveReceiptPhoto(File(pickedFile.path));

      // Run on-device OCR & heuristic parsing
      final parsed = await _ocrService.processReceiptImage(savedImagePath);

      if (!mounted) return;
      setState(() => _isProcessingOcr = false);

      // Open Review & Correction Dialog
      final result = await showDialog<Receipt>(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => ReviewReceiptDialog(
          initialMerchant: parsed.merchant,
          initialAmount: parsed.amount,
          initialDate: parsed.date,
          initialCategory: parsed.category,
          imagePath: savedImagePath,
          rawOcrText: parsed.rawText,
        ),
      );

      if (result != null && mounted) {
        await context.read<ExpenseProvider>().addReceipt(result);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Saved: ${result.merchant} (${NumberFormat.currency(locale: "vi_VN", symbol: "đ", decimalDigits: 0).format(result.amount)})'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isProcessingOcr = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('OCR Failed: $e'), backgroundColor: Theme.of(context).colorScheme.error),
        );
      }
    }
  }

  Future<void> _handleManualAdd() async {
    final result = await showDialog<Receipt>(
      context: context,
      builder: (ctx) => ReviewReceiptDialog(
        initialMerchant: '',
        initialAmount: 0.0,
        initialDate: DateTime.now(),
        initialCategory: 'Food',
      ),
    );

    if (result != null && mounted) {
      await context.read<ExpenseProvider>().addReceipt(result);
    }
  }

  void _showScanOptions() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Add Expense',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              ListTile(
                leading: const CircleAvatar(
                  child: Icon(Icons.camera_alt_outlined),
                ),
                title: const Text('Capture with Camera'),
                subtitle: const Text('Scan physical receipt with On-Device ML Kit'),
                onTap: () {
                  Navigator.pop(ctx);
                  _handleImageCapture(ImageSource.camera);
                },
              ),
              ListTile(
                leading: const CircleAvatar(
                  child: Icon(Icons.photo_library_outlined),
                ),
                title: const Text('Pick from Gallery'),
                subtitle: const Text('Select an existing receipt image'),
                onTap: () {
                  Navigator.pop(ctx);
                  _handleImageCapture(ImageSource.gallery);
                },
              ),
              ListTile(
                leading: const CircleAvatar(
                  child: Icon(Icons.edit_note_outlined),
                ),
                title: const Text('Manual Entry'),
                subtitle: const Text('Type amount and merchant manually'),
                onTap: () {
                  Navigator.pop(ctx);
                  _handleManualAdd();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  IconData _getCategoryIcon(String category) {
    switch (category) {
      case 'Food':
        return Icons.restaurant;
      case 'Transport':
        return Icons.directions_bus;
      case 'Study':
        return Icons.school;
      case 'Shopping':
        return Icons.shopping_bag_outlined;
      case 'Entertainment':
        return Icons.sports_esports_outlined;
      default:
        return Icons.receipt_long;
    }
  }

  @override
  Widget build(BuildContext context) {
    final currencyFormat = NumberFormat.currency(locale: 'vi_VN', symbol: 'đ', decimalDigits: 0);
    final dateFormat = DateFormat('dd/MM/yyyy');
    final provider = context.watch<ExpenseProvider>();

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('VKU Expense Tracker', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            Text(
              'On-Device ML Kit OCR • Offline SQLite',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(color: Theme.of(context).colorScheme.outline),
            ),
          ],
        ),
        actions: [
          // Sync Button with pending badge
          IconButton(
            tooltip: 'Sync Offline Queue',
            icon: Stack(
              clipBehavior: Clip.none,
              children: [
                provider.isSyncing
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.sync),
                if (provider.pendingSyncCount > 0 && !provider.isSyncing)
                  Positioned(
                    right: -4,
                    top: -4,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(
                        color: Colors.redAccent,
                        shape: BoxShape.circle,
                      ),
                      constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                      child: Text(
                        '${provider.pendingSyncCount}',
                        style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
              ],
            ),
            onPressed: provider.isSyncing
                ? null
                : () async {
                    final synced = await provider.syncPendingReceipts();
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(synced > 0 ? 'Synced $synced receipts to cloud!' : 'All receipts are synced.'),
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    }
                  },
          ),
          // Theme Toggle
          IconButton(
            tooltip: 'Toggle Theme',
            icon: Icon(
              Theme.of(context).brightness == Brightness.dark ? Icons.light_mode : Icons.dark_mode,
            ),
            onPressed: () => provider.toggleTheme(),
          ),
        ],
      ),
      body: Stack(
        children: [
          RefreshIndicator(
            onRefresh: () => provider.loadReceipts(),
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              children: [
                // Summary Balance Card
                Card(
                  elevation: 0,
                  color: Theme.of(context).colorScheme.primaryContainer.withValues(alpha:0.4),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: BorderSide(color: Theme.of(context).colorScheme.primary.withValues(alpha:0.2)),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Total Spending',
                              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                                  ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: Theme.of(context).colorScheme.surface,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    provider.pendingSyncCount > 0 ? Icons.cloud_off : Icons.cloud_done,
                                    size: 14,
                                    color: provider.pendingSyncCount > 0 ? Colors.orange : Colors.green,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    provider.pendingSyncCount > 0 ? '${provider.pendingSyncCount} pending' : 'Synced',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: provider.pendingSyncCount > 0 ? Colors.orange : Colors.green,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          currencyFormat.format(provider.totalSpent),
                          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          '${provider.receipts.length} recorded receipts',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: Theme.of(context).colorScheme.outline,
                              ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Custom Canvas Chart Section
                Card(
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: BorderSide(color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha:0.5)),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      children: [
                        TabBar(
                          controller: _chartTabController,
                          labelColor: Theme.of(context).colorScheme.primary,
                          indicatorColor: Theme.of(context).colorScheme.primary,
                          tabs: const [
                            Tab(icon: Icon(Icons.pie_chart_outline, size: 18), text: 'By Category'),
                            Tab(icon: Icon(Icons.bar_chart_outlined, size: 18), text: 'Weekly Trend'),
                          ],
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          height: 270,
                          child: TabBarView(
                            controller: _chartTabController,
                            children: [
                              // Donut Chart
                              Center(
                                child: DonutChartWidget(
                                  categoryData: provider.categoryTotals,
                                  totalAmount: provider.totalSpent,
                                ),
                              ),
                              // Weekly Bar Chart
                              Center(
                                child: WeeklyBarChartWidget(
                                  weeklyData: provider.weeklyData,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // Transactions Header
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Recent Receipts',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    Text(
                      '${provider.receipts.length} items',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(color: Theme.of(context).colorScheme.outline),
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                // Transactions List
                if (provider.receipts.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 40),
                    child: Center(
                      child: Column(
                        children: [
                          Icon(Icons.receipt_outlined, size: 48, color: Theme.of(context).colorScheme.outline),
                          const SizedBox(height: 12),
                          Text(
                            'No receipts scanned yet',
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                  color: Theme.of(context).colorScheme.outline,
                                ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Tap the camera button below to scan your first receipt',
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: Theme.of(context).colorScheme.outlineVariant,
                                ),
                          ),
                        ],
                      ),
                    ),
                  )
                else
                  ...provider.receipts.map((receipt) {
                    final color = DonutChartWidget.categoryColors[receipt.category] ?? Colors.grey;

                    return Dismissible(
                      key: Key('receipt_${receipt.id}'),
                      direction: DismissDirection.endToStart,
                      background: Container(
                        alignment: Alignment.centerRight,
                        padding: const EdgeInsets.only(right: 20),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.errorContainer,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(Icons.delete_outline, color: Theme.of(context).colorScheme.onErrorContainer),
                      ),
                      onDismissed: (_) {
                        if (receipt.id != null) {
                          provider.deleteReceipt(receipt.id!);
                        }
                      },
                      child: Card(
                        elevation: 0,
                        margin: const EdgeInsets.only(bottom: 8),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: BorderSide(color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha:0.3)),
                        ),
                        child: ListTile(
                          onTap: () async {
                            final updated = await showDialog<Receipt>(
                              context: context,
                              builder: (ctx) => ReviewReceiptDialog(
                                initialMerchant: receipt.merchant,
                                initialAmount: receipt.amount,
                                initialDate: receipt.date,
                                initialCategory: receipt.category,
                                imagePath: receipt.imagePath,
                                rawOcrText: receipt.rawOcrText,
                                existingId: receipt.id,
                              ),
                            );
                            if (updated != null && mounted) {
                              await provider.updateReceipt(updated);
                            }
                          },
                          leading: CircleAvatar(
                            backgroundColor: color.withValues(alpha:0.15),
                            child: Icon(_getCategoryIcon(receipt.category), color: color, size: 20),
                          ),
                          title: Text(
                            receipt.merchant,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          subtitle: Row(
                            children: [
                              Text(dateFormat.format(receipt.date)),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: color.withValues(alpha:0.1),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  receipt.category,
                                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: color),
                                ),
                              ),
                            ],
                          ),
                          trailing: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                currencyFormat.format(receipt.amount),
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                  color: Theme.of(context).colorScheme.primary,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Icon(
                                receipt.syncStatus == 'synced' ? Icons.cloud_done_outlined : Icons.cloud_upload_outlined,
                                size: 13,
                                color: receipt.syncStatus == 'synced' ? Colors.green : Colors.orange,
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }),
                const SizedBox(height: 80),
              ],
            ),
          ),

          // Loading Overlay when ML Kit OCR is running
          if (_isProcessingOcr)
            Container(
              color: Colors.black54,
              child: Center(
                child: Card(
                  elevation: 6,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const CircularProgressIndicator(),
                        const SizedBox(height: 16),
                        const Text(
                          'On-Device ML Kit OCR',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Extracting Total, Date & Merchant...',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showScanOptions,
        icon: const Icon(Icons.add_a_photo_outlined),
        label: const Text('Scan Receipt'),
      ),
    );
  }
}
