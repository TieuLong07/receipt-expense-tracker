// ponytail: Settings & API Key dialog; add multi-provider selection (OpenAI, Claude, DeepSeek) when multi-LLM is needed.

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/expense_provider.dart';

class SettingsDialog extends StatefulWidget {
  const SettingsDialog({super.key});

  @override
  State<SettingsDialog> createState() => _SettingsDialogState();
}

class _SettingsDialogState extends State<SettingsDialog> {
  late TextEditingController _keyController;
  bool _obscureKey = true;

  @override
  void initState() {
    super.initState();
    final provider = context.read<ExpenseProvider>();
    _keyController = TextEditingController(text: provider.geminiApiKey ?? '');
  }

  @override
  void dispose() {
    _keyController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ExpenseProvider>();

    return AlertDialog(
      title: Row(
        children: [
          Icon(Icons.settings_outlined, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 10),
          const Text('AI & App Settings', style: TextStyle(fontSize: 18)),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Status Banner
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: provider.isOnline
                    ? Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.4)
                    : Theme.of(context).colorScheme.errorContainer.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  Icon(
                    provider.isOnline ? Icons.wifi : Icons.wifi_off,
                    color: provider.isOnline ? Colors.green : Colors.red,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      provider.isOnline
                          ? 'Online Mode: Gemini Flash AI Active'
                          : 'Offline Mode: Receipts will be Queued',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: provider.isOnline
                            ? Theme.of(context).colorScheme.onPrimaryContainer
                            : Theme.of(context).colorScheme.onErrorContainer,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Gemini API Key Input
            Text(
              'Google Gemini API Key',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(
              'Used for high-precision receipt extraction & multi-item parsing. Free at aistudio.google.com.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.outline),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _keyController,
              obscureText: _obscureKey,
              decoration: InputDecoration(
                labelText: 'Gemini API Key',
                hintText: 'AIzaSy...',
                border: const OutlineInputBorder(),
                prefixIcon: const Icon(Icons.key_outlined),
                suffixIcon: IconButton(
                  icon: Icon(_obscureKey ? Icons.visibility_off : Icons.visibility),
                  onPressed: () => setState(() => _obscureKey = !_obscureKey),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Offline Queue Stats
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.5)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Offline Processing Queue', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                      Text('${provider.queuedCount} receipts waiting for AI', style: TextStyle(fontSize: 11, color: Theme.of(context).colorScheme.outline)),
                    ],
                  ),
                  if (provider.queuedCount > 0)
                    FilledButton.tonal(
                      onPressed: provider.isOnline
                          ? () async {
                              final count = await provider.processQueuedReceipts();
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('Processed $count queued receipts!')),
                                );
                              }
                            }
                          : null,
                      child: const Text('Process Now', style: TextStyle(fontSize: 11)),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () async {
            await provider.setGeminiApiKey(_keyController.text.trim());
            if (context.mounted) {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Settings saved successfully!')),
              );
            }
          },
          child: const Text('Save Settings'),
        ),
      ],
    );
  }
}
