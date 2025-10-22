import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:path_provider/path_provider.dart';
import 'core/models.dart';
import 'core/mock_backend_service.dart'; 
import 'features/auth/application/auth_notifier.dart'; 
import 'features/auth/presentation/login_screen.dart';
import 'features/inventory/presentation/inventory_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final appDocumentDir = await getApplicationDocumentsDirectory();
  await Hive.initFlutter(appDocumentDir.path);

  Hive.registerAdapter(AppRoleAdapter());
  Hive.registerAdapter(AppUserAdapter());
  Hive.registerAdapter(ProductAdapter());
  Hive.registerAdapter(ProductAuditEntryAdapter());
  Hive.registerAdapter(OfflineOperationAdapter());
  Hive.registerAdapter(OperationTypeAdapter());

  await Hive.openBox<AppUser>('sessionBox');
  final productBox = await Hive.openBox<Product>('productBox');
  await Hive.openBox<OfflineOperation>('queueBox');
  final auditBox = await Hive.openBox<ProductAuditEntry>('auditBox');

  runApp(
    ProviderScope(
      overrides: [
        mockBackendServiceProvider.overrideWithValue(
          MockBackendService(productBox, auditBox),
        ),
      ],
      child: const InventoryApp(),
    ),
  );
}

class InventoryApp extends StatelessWidget {
  const InventoryApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Collaborative Inventory',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.indigo,
        useMaterial3: true,
        inputDecorationTheme: const InputDecorationTheme(
          border: OutlineInputBorder(
            borderRadius: BorderRadius.all(Radius.circular(12)),
          ),
          contentPadding: EdgeInsets.symmetric(vertical: 16, horizontal: 12),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            textStyle: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
      home: Consumer(
        builder: (context, ref, child) {
          final user = ref.watch(authProvider);
          if (user != null) {
            return const InventoryScreen();
          }
          return const LoginScreen();
        },
      ),
    );
  }
}
