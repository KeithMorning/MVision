import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:design_system/design_system.dart';

void main() {
  runApp(
    const ProviderScope(
      child: MVisionApp(),
    ),
  );
}

class MVisionApp extends StatelessWidget {
  const MVisionApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MVision',
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: ThemeMode.system,
      home: const Scaffold(
        body: Center(
          child: Text('MVision - Phase 0'),
        ),
      ),
    );
  }
}
