import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive/hive.dart';
import '../../../../core/connectivity_service.dart';
import '../../../../core/models.dart';
import '../../../../core/mock_backend_service.dart';
import '../../auth/application/auth_notifier.dart';
import 'offline_queue_service.dart';

class InventoryManager extends StateNotifier<List<Product>> {
  final Ref _ref;
  final Box<Product> _productBox;
  final MockBackendService _backendService;
  final OfflineQueueService _queueService;

  InventoryManager(
    this._ref,
    List<Product> initialState,
    this._productBox,
    this._backendService,
    this._queueService,
  ) : super(initialState) {
    _ref.listen<AsyncValue<bool>>(isOnlineProvider, (prev, next) {
      if (next.value == true) {
        handleOnlineTransition();
      }
    });

    _initializeData();
  }
  void _initializeData() async {
    final cachedProducts = List<Product>.from(_productBox.values);
    if (cachedProducts.isNotEmpty) {
      state = cachedProducts;
    }

    await fetchProducts();
  }

  Future<void> fetchProducts() async {
    try {
      final remoteProducts = (await _backendService.fetchProducts()).toList();
      final currentStateMap = {for (var p in state) p.id: p};
      final List<Product> mergedProducts = [];
      for (final remoteP in remoteProducts) {
        final localP = currentStateMap[remoteP.id];
        if (localP != null) {
          mergedProducts.add(remoteP.copyWith(isPending: localP.isPending));
        } else {
          mergedProducts.add(remoteP);
        }
      }

      state = mergedProducts;

      await _productBox.clear();
      for (var p in mergedProducts) {
        await _productBox.put(p.id, p);
      }

      debugPrint('Products successfully fetched and cached.');
    } catch (e) {
      debugPrint('Failed to fetch products: $e');
      if (state.isEmpty) {
        state = List<Product>.from(_productBox.values);
      }
    }
  }

  void handleOnlineTransition() async {
    final user = _ref.read(authProvider);
    if (user == null) return;

    debugPrint('Network recovered. Attempting to sync offline queue...');
    final failedOps = await _queueService.syncQueue(user.email);

    await fetchProducts();

    final currentlyQueuedIds = _queueService
        .getOperations()
        .map((op) => op.targetProductId)
        .toSet();

    state = state.map((p) {
      return p.isPending && !currentlyQueuedIds.contains(p.id)
          ? p.copyWith(isPending: false)
          : p;
    }).toList();
    if (failedOps.isNotEmpty) {
      debugPrint(
        '${failedOps.length} operations failed synchronization and need user attention.',
      );
    }
  }

  Future<void> updateStock(String productId, int delta) async {
    final isOnline = await _ref.read(connectivityServiceProvider).isOnline;
    final user = _ref.read(authProvider)!;

    final productIndex = state.indexWhere((p) => p.id == productId);
    if (productIndex == -1) return;

    final oldProduct = state[productIndex];
    final newStock = oldProduct.stock + delta;

    final optimisticProduct = oldProduct.copyWith(
      stock: newStock,
      isPending: true,
      lastUpdated: DateTime.now(),
    );

    state = List<Product>.from(state)..[productIndex] = optimisticProduct;

    if (isOnline) {
      try {
        final remoteProduct = await _backendService.updateStock(
          productId: productId,
          newStock: newStock,
          userEmail: user.email,
          clientTimestamp: optimisticProduct.lastUpdated,
        );

        final finalIndex = state.indexWhere((p) => p.id == productId);
        if (finalIndex != -1) {
          final newState = List<Product>.from(state);
          newState[finalIndex] = remoteProduct.copyWith(isPending: false);
          state = newState;
          await _productBox.put(remoteProduct.id, state[finalIndex]);
          debugPrint('Online update SUCCESS for $productId');
        }
      } catch (e) {
        final errorString = e.toString();
        debugPrint('Optimistic update failed for $productId: $errorString');

        if (errorString.contains('CONFILCT_409')) {
          debugPrint('Conflict detected. Forcing product refresh.');
          await fetchProducts();
        } else if (errorString.contains('NETWORK_ERROR') ||
            errorString.contains('SERVER_ERROR_500')) {
          debugPrint(
            'Online attempt failed due to network/server error. Queuing operation.',
          );
          await _queueOperation(productId, delta);

          final pendingProduct = oldProduct.copyWith(
            stock: newStock,
            isPending: true,
          );
          final newState = List<Product>.from(state);
          newState[productIndex] = pendingProduct;
          state = newState;
          await _productBox.put(pendingProduct.id, pendingProduct);
        } else {
          debugPrint('Unknown error. Rolling back UI.');
          final finalIndex = state.indexWhere((p) => p.id == productId);
          if (finalIndex != -1) {
            final newState = List<Product>.from(state);
            newState[finalIndex] = oldProduct.copyWith(isPending: false);
            state = newState;
            await _productBox.put(oldProduct.id, state[finalIndex]);
          }
        }
      }
    } else {
      await _queueOperation(productId, delta);
      await _productBox.put(optimisticProduct.id, optimisticProduct);
    }
  }

  Future<void> _queueOperation(String productId, int delta) async {
    final operation = OfflineOperation(
      type: OperationType.updateStock,
      targetProductId: productId,
      stockChange: delta,
      queuedAt: DateTime.now(),
    );
    await _queueService.enqueue(operation);
  }

  Future<void> createProduct(String name, int stock) async {
    final isOnline = _ref.read(connectivityServiceProvider).isOnline;
    final user = _ref.read(authProvider)!;

    final tempId = 'temp-${DateTime.now().millisecondsSinceEpoch}';

    final newProduct = Product(
      id: tempId,
      name: name,
      stock: stock,
      isSynced: isOnline,
    )..isPending = !isOnline;
    state = [newProduct, ...state];
    await _productBox.put(newProduct.id, newProduct);

    if (isOnline) {
      try {
        final remoteProduct = await _backendService.createProduct(
          newProduct,
          user.email,
        );

        await _productBox.delete(tempId);

        for (var p in _productBox.values.where((p) => p.name == name)) {
          await _productBox.delete(p.id);
        }

        await _productBox.put(remoteProduct.id, remoteProduct);

        state = [
          remoteProduct.copyWith(isSynced: true, isPending: false),
          ...state.where((p) => p.id != tempId && p.name != name),
        ];

        debugPrint('Synced new product successfully.');
      } catch (e) {
        debugPrint('Online product creation failed: $e');

        await _queueService.enqueue(
          OfflineOperation(
            type: OperationType.createProduct,
            targetProductId: tempId,
            payloadJson: jsonEncode({'name': name, 'stock': stock}),
          ),
        );
      }
    } else {
      await _queueService.enqueue(
        OfflineOperation(
          type: OperationType.createProduct,
          targetProductId: tempId,
          payloadJson: jsonEncode({'name': name, 'stock': stock}),
        ),
      );

      debugPrint('📴 Product queued for sync when online.');
    }
  }

  Future<void> discardOperation(String operationId) async {
    final op = _queueService.getOperations().firstWhere(
      (o) => o.id == operationId,
    );

    await _queueService.dequeue(operationId);

    if (op.type == OperationType.createProduct) {
      state = state.where((p) => p.id != op.targetProductId).toList();
      await _productBox.delete(op.targetProductId);
    }

    final productIndex = state.indexWhere((p) => p.id == op.targetProductId);
    if (productIndex != -1) {
      final updatedProduct = state[productIndex].copyWith(isPending: false);
      final newState = List<Product>.from(state);
      newState[productIndex] = updatedProduct;
      state = newState;
      await _productBox.put(updatedProduct.id, updatedProduct);
    }
  }

  Future<void> deleteProduct(String productId) async {
    final isOnline = await _ref.read(connectivityServiceProvider).isOnline;
    final user = _ref.read(authProvider)!;

    state = state.where((p) => p.id != productId).toList();

    if (isOnline) {
      try {
        await _backendService.deleteProduct(productId, user.email);
        await _productBox.delete(productId);
      } catch (e) {
        await fetchProducts();
        debugPrint('Delete failed: $e');
      }
    } else {
      final operation = OfflineOperation(
        type: OperationType.deleteProduct,
        targetProductId: productId,
      );
      await _queueService.enqueue(operation);

      await _productBox.delete(productId);
    }
  }
}

final inventoryManagerProvider =
    StateNotifierProvider<InventoryManager, List<Product>>((ref) {
      final productBox = Hive.box<Product>('productBox');
      final backendService = ref.watch(mockBackendServiceProvider);
      final queueService = ref.read(offlineQueueServiceProvider.notifier);

      final initialState = productBox.values.toList();

      return InventoryManager(
        ref,
        initialState,
        productBox,
        backendService,
        queueService,
      );
    });

final isProductQueuedProvider = Provider.family<bool, String>((ref, productId) {
  final queue = ref.watch(offlineQueueProvider);
  return queue.any((op) => op.targetProductId == productId);
});

final productAuditLogProvider =
    FutureProvider.family<List<ProductAuditEntry>, String>((
      ref,
      productId,
    ) async {
      final backendService = ref.watch(mockBackendServiceProvider);
      return backendService.fetchAuditHistory(productId);
    });
