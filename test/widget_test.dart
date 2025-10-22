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


// Mock necessary dependencies
class MockAuthService extends Mock implements AuthService {}
class MockMockBackendService extends Mock implements MockBackendService {}
class MockBox<T> extends Mock implements Box<T> {}

// Custom listener to track state changes in providers
class Listener<T> extends Mock {
  void call(T? previous, T next);
}

void main() {
  // Set up Hive for testing (Using a temporary directory)
  setUpAll(() async {
    // Note: Hive init path is typically handled by path_provider, but for testing, we mock
    Hive.init('test/hive_temp');
    // Register all adapters
    Hive.registerAdapter(AppRoleAdapter());
    Hive.registerAdapter(AppUserAdapter());
    Hive.registerAdapter(ProductAdapter());
    Hive.registerAdapter(ProductAuditEntryAdapter());
    Hive.registerAdapter(OfflineOperationAdapter());
    Hive.registerAdapter(OperationTypeAdapter());
    
    // FIX 1: Register fallback for AppRole (needed for hasPermission(any(), any()))
    registerFallbackValue(AppRole.viewer);
    
    // Register fallback for OfflineOperation
    registerFallbackValue(OfflineOperation(type: OperationType.updateStock, targetProductId: 'id'));
  });

  // Clean up Hive after all tests
  tearDownAll(() async {
    await Hive.close();
  });
  
  // Create mock boxes for providers
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
    
    // Default mocks for setup 
    when(() => mockAuthService.initialize()).thenReturn(null);
    when(() => mockAuthService.hasPermission(any(), any())).thenReturn(true);
    
    // FIX: Initialize container with all necessary overrides (3 total), including the service being unit tested.
    container = ProviderContainer(
      overrides: [
        mockBackendServiceProvider.overrideWithValue(mockBackendService),
        authServiceProvider.overrideWithValue(mockAuthService),
        // This ensures the initial override list length is 3 for all tests
        offlineQueueServiceProvider.overrideWith((ref) => OfflineQueueService([], mockQueueBox, mockBackendService)),
      ],
    );
  });
  
  tearDown(() {
    container.dispose();
  });


  // --- UNIT TEST: Offline Queue Logic ---
  group('OfflineQueueService Unit Test', () {
    
    test('enqueue adds an operation to the Hive box and notifies listeners', () async {
      final listener = Listener<List<OfflineOperation>>();
      
      // FIX: Removed container.updateOverrides because the override is now set in setUp
      
      // Listen to the queue provider
      container.listen(offlineQueueProvider, listener, fireImmediately: true);

      // Initial state is an empty list
      verify(() => listener(null, []));

      final operation = OfflineOperation(
        type: OperationType.updateStock, 
        targetProductId: 'p001', 
        stockChange: 5
      );

      // Mock Hive behavior: when values are requested, return the new operation
      when(() => mockQueueBox.values).thenReturn([operation]);
      when(() => mockQueueBox.put(any(), any())).thenAnswer((_) async {});
      
      // Read the notifier (the service instance) and call enqueue
      await container.read(offlineQueueServiceProvider.notifier).enqueue(operation);

      // Verify put was called
      verify(() => mockQueueBox.put(operation.id, operation)).called(1);
      
      // Verify listeners were notified of the change
      verify(() => listener([], [operation])).called(1);
    });
  });

  // --- WIDGET TEST: RBAC Enforcement in ProductTile ---
  group('ProductTile Widget Test', () {
    final testProduct = Product(
      id: 'p001',
      name: 'Test Product',
      stock: 10,
    );

    testWidgets('Manager sees stock edit controls', (tester) async {
      // Setup: Manager user (has manager permission, but not admin)
      // FIX 2: Explicitly mock hasPermission for the roles being checked in ProductTile
      when(() => mockAuthService.hasPermission(any(), AppRole.manager)).thenReturn(true);
      when(() => mockAuthService.hasPermission(any(), AppRole.admin)).thenReturn(false);

      await tester.pumpWidget(
        ProviderScope(
          parent: container,
          overrides: [
            // Mock the InventoryManager to prevent actual state changes during UI testing
            // NOTE: Must read the .notifier of the queue service here
            inventoryManagerProvider.overrideWith((ref) => InventoryManager(ref, [testProduct], mockProductBox, mockBackendService, container.read(offlineQueueServiceProvider.notifier))),
            isProductQueuedProvider('p001').overrideWithValue(false),
          ],
          child: MaterialApp(home: ProductTile(product: testProduct)),
        ),
      );

      // Verify the increase and decrease buttons are present
      expect(find.byIcon(Icons.add_circle_outline), findsOneWidget);
      expect(find.byIcon(Icons.remove_circle_outline), findsOneWidget);
      // Verify the Admin-only delete button is NOT present
      expect(find.byIcon(Icons.delete), findsNothing);
    });

    testWidgets('Viewer does NOT see stock edit controls', (tester) async {
      // Setup: Viewer user (no manager or admin permission)
      when(() => mockAuthService.hasPermission(any(), AppRole.manager)).thenReturn(false); 
      when(() => mockAuthService.hasPermission(any(), AppRole.admin)).thenReturn(false); 

      await tester.pumpWidget(
        ProviderScope(
          parent: container,
          overrides: [
            // NOTE: Must read the .notifier of the queue service here
            inventoryManagerProvider.overrideWith((ref) => InventoryManager(ref, [testProduct], mockProductBox, mockBackendService, container.read(offlineQueueServiceProvider.notifier))),
            isProductQueuedProvider('p001').overrideWithValue(false),
          ],
          child: MaterialApp(home: ProductTile(product: testProduct)),
        ),
      );

      // Verify the increase and decrease buttons are NOT present
      expect(find.byIcon(Icons.add_circle_outline), findsNothing);
      expect(find.byIcon(Icons.remove_circle_outline), findsNothing);
      // Viewer still sees the history button
      expect(find.byIcon(Icons.history), findsOneWidget);
    });
    
     testWidgets('Admin sees stock edit and delete controls', (tester) async {
      // Setup: Admin user
      when(() => mockAuthService.hasPermission(any(), AppRole.manager)).thenReturn(true);
      when(() => mockAuthService.hasPermission(any(), AppRole.admin)).thenReturn(true); 

      await tester.pumpWidget(
        ProviderScope(
          parent: container,
          overrides: [
            // NOTE: Must read the .notifier of the queue service here
            inventoryManagerProvider.overrideWith((ref) => InventoryManager(ref, [testProduct], mockProductBox, mockBackendService, container.read(offlineQueueServiceProvider.notifier))),
            isProductQueuedProvider('p001').overrideWithValue(false),
          ],
          child: MaterialApp(home: ProductTile(product: testProduct)),
        ),
      );

      // Verify the increase and decrease buttons are present (Manager permission)
      expect(find.byIcon(Icons.add_circle_outline), findsOneWidget);
      expect(find.byIcon(Icons.remove_circle_outline), findsOneWidget);
      // Verify the Admin-only delete button is present
      expect(find.byIcon(Icons.delete), findsOneWidget);
    });
  });
}
