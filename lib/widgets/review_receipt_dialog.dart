// ponytail: Material 3 Review & Item list dialog; add barcode barcode scanning when inventory tracking is required.

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/receipt.dart';

class ReviewReceiptDialog extends StatefulWidget {
  final String initialMerchant;
  final double initialAmount;
  final double initialSubtotal;
  final DateTime initialDate;
  final String initialCategory;
  final List<ReceiptItem> initialItems;
  final String? imagePath;
  final String? rawOcrText;
  final int? existingId;
  final String engineName;

  const ReviewReceiptDialog({
    super.key,
    required this.initialMerchant,
    required this.initialAmount,
    this.initialSubtotal = 0.0,
    required this.initialDate,
    required this.initialCategory,
    this.initialItems = const [],
    this.imagePath,
    this.rawOcrText,
    this.existingId,
    this.engineName = 'Cloudflare AI Vision',
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
  late List<ReceiptItem> _items;

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
    _items = List.from(widget.initialItems);
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

  void _addNewItem() {
    final nameCtrl = TextEditingController();
    final priceCtrl = TextEditingController();
    final qtyCtrl = TextEditingController(text: '1');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add Item', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtrl,
              autofocus: true,
              decoration: const InputDecoration(labelText: 'Item Name', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: qtyCtrl,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(labelText: 'Quantity', border: OutlineInputBorder()),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  flex: 2,
                  child: TextField(
                    controller: priceCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Total Price', border: OutlineInputBorder(), suffixText: 'đ'),
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            onPressed: () {
              final name = nameCtrl.text.trim();
              final price = double.tryParse(priceCtrl.text.replaceAll(RegExp(r'[.,\s]'), '')) ?? 0.0;
              final qty = double.tryParse(qtyCtrl.text.replaceAll(',', '.')) ?? 1.0;
              if (name.isNotEmpty && price > 0) {
                setState(() {
                  _items.add(ReceiptItem(name: name, quantity: qty, unitPrice: price / (qty > 0 ? qty : 1), totalPrice: price));
                  final newSum = _items.fold(0.0, (sum, i) => sum + i.totalPrice);
                  _amountController.text = newSum.toStringAsFixed(0);
                });
                Navigator.pop(ctx);
              }
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
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
        items: _items,
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
    final currencyFormat = NumberFormat.currency(locale: 'vi_VN', symbol: 'đ', decimalDigits: 0);
    final itemsSubtotal = _items.fold(0.0, (sum, i) => sum + i.totalPrice);

    return AlertDialog(
      title: Row(
        children: [
          Icon(Icons.receipt_long_outlined, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              widget.existingId == null ? 'Verify Extracted Receipt' : 'Edit Expense',
              style: const TextStyle(fontSize: 18),
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: double.maxFinite,
        child: SingleChildScrollView(
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
                      height: 130,
                      width: double.infinity,
                      fit: BoxFit.cover,
                    ),
                  ),
                  const SizedBox(height: 12),
                ],

                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.auto_awesome, size: 16, color: Theme.of(context).colorScheme.primary),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          _items.isNotEmpty
                              ? 'Extracted ${_items.length} items with ${widget.engineName}'
                              : 'Analyzed by ${widget.engineName}',
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

                // Quick selector chips if subtotal != payable total (e.g. vouchers, store credits)
                if (widget.initialSubtotal > 0 && widget.initialSubtotal != widget.initialAmount) ...[
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: [
                      ActionChip(
                        avatar: const Icon(Icons.check_circle_outline, size: 14),
                        label: Text('Thực trả: ${currencyFormat.format(widget.initialAmount)}'),
                        onPressed: () {
                          setState(() {
                            _amountController.text = widget.initialAmount.toStringAsFixed(0);
                          });
                        },
                      ),
                      ActionChip(
                        avatar: const Icon(Icons.shopping_cart_outlined, size: 14),
                        label: Text('Tổng hàng: ${currencyFormat.format(widget.initialSubtotal)}'),
                        onPressed: () {
                          setState(() {
                            _amountController.text = widget.initialSubtotal.toStringAsFixed(0);
                          });
                        },
                      ),
                    ],
                  ),
                ],

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
                const SizedBox(height: 18),

                // Item Breakdown Section
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Purchased Items (${_items.length})',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    TextButton.icon(
                      onPressed: _addNewItem,
                      icon: const Icon(Icons.add, size: 16),
                      label: const Text('Add Item', style: TextStyle(fontSize: 12)),
                      style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
                    ),
                  ],
                ),
                const SizedBox(height: 6),

                if (_items.isEmpty)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.5)),
                    ),
                    child: Text(
                      'No individual line items parsed. You can tap "Add Item" above to add items manually.',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.outline),
                    ),
                  )
                else
                  Container(
                    decoration: BoxDecoration(
                      border: Border.all(color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.5)),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      children: [
                        ..._items.asMap().entries.map((entry) {
                          final idx = entry.key;
                          final item = entry.value;
                          final isLast = idx == _items.length - 1;
                          final qtyStr = item.quantity == 1.0 ? '' : ' • ${item.quantity.toStringAsFixed(item.quantity.truncateToDouble() == item.quantity ? 0 : 3)} kg';

                          return Container(
                            decoration: BoxDecoration(
                              border: isLast ? null : Border(bottom: BorderSide(color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.3))),
                            ),
                            child: ListTile(
                              dense: true,
                              visualDensity: VisualDensity.compact,
                              title: Text(item.name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                              subtitle: Text(
                                '${currencyFormat.format(item.totalPrice)}$qtyStr',
                                style: TextStyle(fontSize: 11, color: Theme.of(context).colorScheme.primary),
                              ),
                              trailing: IconButton(
                                icon: const Icon(Icons.close, size: 16),
                                onPressed: () {
                                  setState(() {
                                    _items.removeAt(idx);
                                    if (_items.isNotEmpty) {
                                      final newSum = _items.fold(0.0, (sum, i) => sum + i.totalPrice);
                                      _amountController.text = newSum.toStringAsFixed(0);
                                    }
                                  });
                                },
                              ),
                            ),
                          );
                        }),
                        if (itemsSubtotal > 0)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                            color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.2),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text('Items Subtotal:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                                Text(
                                  currencyFormat.format(itemsSubtotal),
                                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Theme.of(context).colorScheme.primary),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
              ],
            ),
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
