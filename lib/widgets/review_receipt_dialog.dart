// ponytail: Material 3 Review & Correction Dialog; add full-screen zoomable crop editor if users need to re-align receipt corners.

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/receipt.dart';

class ReviewReceiptDialog extends StatefulWidget {
  final String initialMerchant;
  final double initialAmount;
  final DateTime initialDate;
  final String initialCategory;
  final String? imagePath;
  final String? rawOcrText;
  final int? existingId;

  const ReviewReceiptDialog({
    super.key,
    required this.initialMerchant,
    required this.initialAmount,
    required this.initialDate,
    required this.initialCategory,
    this.imagePath,
    this.rawOcrText,
    this.existingId,
  });

  @override
  State<ReviewReceiptDialog> createState() => _ReviewReceiptDialogState();
}

class _ReviewReceiptDialogState extends State<ReviewReceiptDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _merchantController;
  late TextEditingController _amountController;
  late DateTime _selectedDate;
  late String _selectedCategory;

  static const List<String> _categories = [
    'Food',
    'Transport',
    'Study',
    'Shopping',
    'Entertainment',
    'Other',
  ];

  @override
  void initState() {
    super.initState();
    _merchantController = TextEditingController(text: widget.initialMerchant);
    _amountController = TextEditingController(
      text: widget.initialAmount > 0 ? widget.initialAmount.toStringAsFixed(0) : '',
    );
    _selectedDate = widget.initialDate;
    _selectedCategory = _categories.contains(widget.initialCategory) ? widget.initialCategory : 'Other';
  }

  @override
  void dispose() {
    _merchantController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 30)),
    );
    if (picked != null) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  void _submit() {
    if (_formKey.currentState?.validate() ?? false) {
      final cleanAmount = _amountController.text.replaceAll(RegExp(r'[.,\s]'), '');
      final amount = double.tryParse(cleanAmount) ?? 0.0;

      final receipt = Receipt(
        id: widget.existingId,
        merchant: _merchantController.text.trim(),
        amount: amount,
        date: _selectedDate,
        category: _selectedCategory,
        imagePath: widget.imagePath,
        rawOcrText: widget.rawOcrText,
        syncStatus: 'pending_sync',
      );

      Navigator.of(context).pop(receipt);
    }
  }

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('dd/MM/yyyy');

    return AlertDialog(
      title: Row(
        children: [
          Icon(Icons.rate_review_outlined, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 10),
          Text(widget.existingId == null ? 'Verify Extracted Receipt' : 'Edit Expense'),
        ],
      ),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (widget.imagePath != null && File(widget.imagePath!).existsSync()) ...[
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.file(
                    File(widget.imagePath!),
                    height: 140,
                    width: double.infinity,
                    fit: BoxFit.cover,
                  ),
                ),
                const SizedBox(height: 12),
              ],
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primaryContainer.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.auto_awesome, size: 16, color: Theme.of(context).colorScheme.primary),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Extracted by On-Device ML Kit & Regex Engine',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              fontWeight: FontWeight.w600,
                              color: Theme.of(context).colorScheme.onPrimaryContainer,
                            ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              // Merchant Input
              TextFormField(
                controller: _merchantController,
                decoration: const InputDecoration(
                  labelText: 'Merchant / Store Name',
                  prefixIcon: Icon(Icons.storefront_outlined),
                  border: OutlineInputBorder(),
                ),
                validator: (val) => (val == null || val.trim().isEmpty) ? 'Please enter merchant name' : null,
              ),
              const SizedBox(height: 14),
              // Amount Input
              TextFormField(
                controller: _amountController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Total Amount (VND)',
                  prefixIcon: Icon(Icons.payments_outlined),
                  border: OutlineInputBorder(),
                  suffixText: 'đ',
                ),
                validator: (val) {
                  if (val == null || val.trim().isEmpty) return 'Please enter total amount';
                  final clean = val.replaceAll(RegExp(r'[.,\s]'), '');
                  if (double.tryParse(clean) == null) return 'Invalid number';
                  return null;
                },
              ),
              const SizedBox(height: 14),
              // Date Picker Field
              InkWell(
                onTap: _pickDate,
                borderRadius: BorderRadius.circular(4),
                child: InputDecorator(
                  decoration: const InputDecoration(
                    labelText: 'Receipt Date',
                    prefixIcon: Icon(Icons.calendar_today_outlined),
                    border: OutlineInputBorder(),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(dateFormat.format(_selectedDate)),
                      const Icon(Icons.arrow_drop_down),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 14),
              // Category Dropdown
              DropdownButtonFormField<String>(
                value: _selectedCategory,
                decoration: const InputDecoration(
                  labelText: 'Expense Category',
                  prefixIcon: Icon(Icons.category_outlined),
                  border: OutlineInputBorder(),
                ),
                items: _categories.map((c) {
                  return DropdownMenuItem(value: c, child: Text(c));
                }).toList(),
                onChanged: (val) {
                  if (val != null) {
                    setState(() => _selectedCategory = val);
                  }
                },
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton.icon(
          onPressed: _submit,
          icon: const Icon(Icons.check, size: 18),
          label: const Text('Confirm & Save'),
        ),
      ],
    );
  }
}
