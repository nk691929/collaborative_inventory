import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:inventory/core/mock_backend_service.dart';
import 'package:inventory/core/models.dart';
import 'package:inventory/features/auth/application/auth_notifier.dart';
import 'package:inventory/features/auth/application/auth_service.dart';
import 'package:inventory/features/inventory/application/inventory_manager.dart';
import 'package:inventory/features/inventory/application/offline_queue_service.dart';
import 'package:inventory/features/inventory/presentation/widget/product_tile.dart';
import 'package:mocktail/mocktail.dart';


class MockAuthService extends Mock implements AuthService {}
class MockMockBackendService extends Mock implements MockBackendService {}
class MockBox<T> extends Mock implements Box<T> {}

class Listener<T> extends Mock {
  void call(T? previous, T next);
}

void main() {
  setUpAll(() async {
    Hive.init('test/hive_temp');
    Hive.registerAdapter(AppRoleAdapter());
    Hive.registerAdapter(AppUserAdapter());
    Hive.registerAdapter(ProductAdapter());
    Hive.registerAdapter(ProductAuditEntryAdapter());
    Hive.registerAdapter(OfflineOperationAdapter());
    Hive.registerAdapter(OperationTypeAdapter());
    
    registerFallbackValue(AppRole.viewer);
    
    registerFallbackValue(OfflineOperation(type: OperationType.updateStock, targetProductId: 'id'));
  });

  tearDownAll(() async {
    await Hive.close();
  });
  
  late Box<Product> mockProductBox;
  late Box<OfflineOperation> mockQueueBox;
  late MockAuthService mockAuthService;
  late MockMockBackendService mockBackendService;
  late ProviderContainer container;

  setUp(() {
    mockProductBox = MockBox<Product>();
    mockQueueBox = MockBox<OfflineOperation>();
    mockAuthService = MockAuthService();
    mockBackendService = MockMockBackendService();
    
    // We mock initialize() to return null, meaning the user is logged out initially.
    when(() => mockAuthService.initialize()).thenReturn(null); 
    
    // This global mock is used by the InventoryManager unit test, but we will use specific overrides in widget tests.
    when(() => mockAuthService.hasPermission(any(), any())).thenReturn(true); 
    
    container = ProviderContainer(
      overrides: [
        mockBackendServiceProvider.overrideWithValue(mockBackendService),
        authServiceProvider.overrideWithValue(mockAuthService),
        offlineQueueServiceProvider.overrideWith((ref) => OfflineQueueService([], mockQueueBox, mockBackendService)),
      ],
    );
  });
  
  tearDown(() {
    container.dispose();
  });

  group('OfflineQueueService Unit Test', () {
    
    test('enqueue adds an operation to the Hive box and notifies listeners', () async {
      final listener = Listener<List<OfflineOperation>>();
      container.listen(offlineQueueProvider, listener.call, fireImmediately: true);

      verify(() => listener(null, []));

      final operation = OfflineOperation(
        type: OperationType.updateStock, 
        targetProductId: 'p001', 
        stockChange: 5
      );

      when(() => mockQueueBox.values).thenReturn([operation]);
      when(() => mockQueueBox.put(any(), any())).thenAnswer((_) async {});
      
      await container.read(offlineQueueServiceProvider.notifier).enqueue(operation);

      verify(() => mockQueueBox.put(operation.id, operation)).called(1);
      
      verify(() => listener([], [operation])).called(1);
    });
  });

  group('ProductTile Widget Test', () {
    final testProduct = Product(
      id: 'p001',
      name: 'Test Product',
      stock: 10,
    );
    
    // Define a mock user to ensure authProvider is not null, which is critical 
    // for the permissionProvider to function correctly in widget tests.
    final mockUser = AppUser(id: 'u1', email: 'test@user.com', role: AppRole.manager);

    testWidgets('Manager sees stock edit controls', (tester) async {
      // FIX: Override specific permission checks and set a non-null authenticated state.
      
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            // Mock permissions required for Manager
            permissionProvider(AppRole.manager).overrideWithValue(true), // Can edit stock
            permissionProvider(AppRole.admin).overrideWithValue(false),  // Cannot delete (only Admin can)
            
            // Override authProvider with a non-null user state
            authProvider.overrideWith((ref) => AuthNotifier(mockAuthService)..state = mockUser),
            
            inventoryManagerProvider.overrideWith((ref) => InventoryManager(ref, [testProduct], mockProductBox, mockBackendService, container.read(offlineQueueServiceProvider.notifier))),
            isProductQueuedProvider('p001').overrideWithValue(false),
          ],
          child: MaterialApp(home: ProductTile(product: testProduct)),
        ),
      );
      
      // Expected Manager controls: Add/Remove, no Delete
      expect(find.byIcon(Icons.add_circle_outline), findsOneWidget);
      expect(find.byIcon(Icons.remove_circle_outline), findsOneWidget);
      expect(find.byIcon(Icons.delete), findsNothing);
    });

    testWidgets('Viewer does NOT see stock edit controls', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            // Mock permissions required for Viewer
            permissionProvider(AppRole.manager).overrideWithValue(false), // Cannot edit stock
            permissionProvider(AppRole.admin).overrideWithValue(false),  // Cannot delete
            
            // Override authProvider with a non-null user state (for consistency)
            authProvider.overrideWith((ref) => AuthNotifier(mockAuthService)..state = mockUser),
            
            inventoryManagerProvider.overrideWith((ref) => InventoryManager(ref, [testProduct], mockProductBox, mockBackendService, container.read(offlineQueueServiceProvider.notifier))),
            isProductQueuedProvider('p001').overrideWithValue(false),
          ],
          child: MaterialApp(home: ProductTile(product: testProduct)),
        ),
      );

      // Expected Viewer controls: No Add/Remove/Delete
      expect(find.byIcon(Icons.add_circle_outline), findsNothing);
      expect(find.byIcon(Icons.remove_circle_outline), findsNothing);
      expect(find.byIcon(Icons.delete), findsNothing);
      expect(find.byIcon(Icons.history), findsOneWidget); 
    });
    
    testWidgets('Admin sees stock edit and delete controls', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            // Mock permissions required for Admin
            permissionProvider(AppRole.manager).overrideWithValue(true), // Can edit stock (Admin is also Manager)
            permissionProvider(AppRole.admin).overrideWithValue(true),  // Can delete
            
            // Override authProvider with a non-null user state
            authProvider.overrideWith((ref) => AuthNotifier(mockAuthService)..state = mockUser),
            
            inventoryManagerProvider.overrideWith((ref) => InventoryManager(ref, [testProduct], mockProductBox, mockBackendService, container.read(offlineQueueServiceProvider.notifier))),
            isProductQueuedProvider('p001').overrideWithValue(false),
          ],
          child: MaterialApp(home: ProductTile(product: testProduct)),
        ),
      );

      // Expected Admin controls: Add/Remove and Delete
      expect(find.byIcon(Icons.add_circle_outline), findsOneWidget);
      expect(find.byIcon(Icons.remove_circle_outline), findsOneWidget);
      expect(find.byIcon(Icons.delete), findsOneWidget);
    });
  });
}
