import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'app/theme.dart';
import 'screens/home_screen.dart';
import 'screens/export_form_screen.dart';
import 'screens/vehicle_form_screen.dart';
import 'screens/vehicle_list_screen.dart';
import 'screens/receipt_scanner_screen.dart';
import 'screens/receipt_form_screen.dart';
import 'screens/receipt_list_screen.dart';
import 'screens/all_receipts_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/edit_receipt_screen.dart';
import 'screens/receipt_image_viewer.dart';
import 'providers/providers.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  // sqflite only works natively on Android/iOS.
  // On Windows/Linux/macOS we need the FFI implementation.
  // Web is unsupported — run on Android or Windows desktop.
  if (!kIsWeb && (Platform.isWindows || Platform.isLinux || Platform.isMacOS)) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  }

  runApp(
    // ProviderScope is required by Riverpod — all providers live here
    const ProviderScope(
      child: MogasApp(),
    ),
  );
}

class MogasApp extends ConsumerWidget {
  const MogasApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);
    return MaterialApp(
      title: 'MOgas MOmoney',
      theme: mogasTheme,
      darkTheme: mogasDarkTheme,
      themeMode: themeMode,
      debugShowCheckedModeBanner: false,
      initialRoute: '/',
      routes: {
        '/': (context) => const HomeScreen(),
        '/export': (context) => const ExportFormScreen(),
        '/add-vehicle': (context) => const VehicleFormScreen(),
        '/vehicles': (context) => const VehicleListScreen(),
        '/scan-receipt': (context) => const ReceiptScannerScreen(),
        '/add-receipt': (context) => const ReceiptFormScreen(),
        '/receipts': (context) => const ReceiptListScreen(),
        '/all-receipts': (context) => const AllReceiptsScreen(),
        '/profile': (context) => const ProfileScreen(),
        '/edit-receipt': (context) => const EditReceiptScreen(),
        '/view-image': (context) => const ReceiptImageViewer(),
      },
    );
  }
}
