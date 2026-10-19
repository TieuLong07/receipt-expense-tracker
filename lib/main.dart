// ponytail: Clean M3 App root with Provider; add multi-language localization when international rollout occurs.

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'providers/expense_provider.dart';
import 'screens/home_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const VKUExpenseApp());
}

class VKUExpenseApp extends StatelessWidget {
  const VKUExpenseApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => ExpenseProvider(),
      child: Consumer<ExpenseProvider>(
        builder: (context, expenseProvider, _) {
          const seedColor = Color(0xFF0F766E); // Deep Teal VKU theme

          return MaterialApp(
            title: 'VKU Receipt Expense Tracker',
            debugShowCheckedModeBanner: false,
            themeMode: expenseProvider.themeMode,
            theme: ThemeData(
              useMaterial3: true,
              colorScheme: ColorScheme.fromSeed(
                seedColor: seedColor,
                brightness: Brightness.light,
              ),
              appBarTheme: const AppBarTheme(
                centerTitle: false,
                elevation: 0,
              ),
            ),
            darkTheme: ThemeData(
              useMaterial3: true,
              colorScheme: ColorScheme.fromSeed(
                seedColor: seedColor,
                brightness: Brightness.dark,
              ),
              appBarTheme: const AppBarTheme(
                centerTitle: false,
                elevation: 0,
              ),
            ),
            home: const HomeScreen(),
          );
        },
      ),
    );
  }
}
