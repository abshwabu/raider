import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'app.dart';
import 'data/local/isar_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final isar = await IsarService.init();

  runApp(
    ProviderScope(
      overrides: [
        isarProvider.overrideWithValue(isar),
      ],
      child: const App(),
    ),
  );
}
