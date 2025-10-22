import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive/hive.dart';
import '../../../../core/mock_backend_service.dart';
import '../../../../core/models.dart';

final offlineQueueBoxProvider = Provider<Box<OfflineOperation>>((ref) {
  return Hive.box<OfflineOperation>('queueBox');
});

final offlineQueueServiceProvider =
    StateNotifierProvider<OfflineQueueService, List<OfflineOperation>>((ref) {
      final queueBox = ref.watch(offlineQueueBoxProvider);
      final backendService = ref.watch(mockBackendServiceProvider);

      final initialState = List<OfflineOperation>.from(queueBox.values);

      return OfflineQueueService(initialState, queueBox, backendService);
    });

final offlineQueueProvider = offlineQueueServiceProvider.select(
  (state) => state,
);

class OfflineQueueService extends StateNotifier<List<OfflineOperation>> {
  final Box<OfflineOperation> _queueBox;
  final MockBackendService _backendService;

  OfflineQueueService(super.initialState, this._queueBox, this._backendService);

  List<OfflineOperation> getOperations() => state;

  Future<void> enqueue(OfflineOperation operation) async {
    await _queueBox.put(operation.id, operation);

    state = [...state, operation];

    debugPrint('Operation ${operation.id} enqueued.');
  }

  Future<void> dequeue(String operationId) async {
    await _queueBox.delete(operationId);
    state = [...state.where((op) => op.id != operationId)];

    debugPrint('Operation $operationId dequeued.');
  }

  Future<List<OfflineOperation>> syncQueue(String userEmail) async {
    final Set<OfflineOperation> failedOpsSet = {};

    final operationsToSync = List<OfflineOperation>.from(state);

    for (final op in operationsToSync) {
      bool success = false;

      try {
        switch (op.type) {
          case OperationType.updateStock:
            final productBox = Hive.box<Product>('productBox');
            final product = productBox.get(op.targetProductId);

            if (product == null) {
              debugPrint('Product not found locally for ${op.targetProductId}');
              continue;
            }

            final newStock = product.stock;

            await _backendService.updateStock(
              productId: op.targetProductId,
              newStock: newStock,
              userEmail: userEmail,
              clientTimestamp: DateTime.now(),
            );

            success = true;
            break;

          case OperationType.createProduct:
            final productBox = Hive.box<Product>('productBox');
            final Map<String, dynamic> payload = jsonDecode(op.payloadJson);

            final tempProduct = Product(
              id: op.targetProductId,
              name: payload['name'],
              stock: payload['stock'],
            );

            final remoteProduct = await _backendService.createProduct(
              tempProduct,
              userEmail,
            );

            await productBox.delete(op.targetProductId);

            await productBox.put(remoteProduct.id, remoteProduct);

            debugPrint(
              'Synced product ${remoteProduct.name} -> ${remoteProduct.id}',
            );

            success = true;
            break;

          case OperationType.deleteProduct:
            await _backendService.deleteProduct(op.targetProductId, userEmail);
            success = true;
            break;

          case OperationType.updateUserRole:
            debugPrint(
              'Skipping user role update operation in inventory queue.',
            );
            success = true;
            break;
        }

        if (success) {
          debugPrint('Operation ${op.id} synced successfully.');
          await dequeue(op.id);
        }
      } catch (e) {
        final errorString = e.toString();
        debugPrint('Sync failed for operation ${op.id}: $errorString');

        if (errorString.contains('CONFILCT_409') ||
            errorString.contains('PERMISSION_DENIED')) {
          failedOpsSet.add(op);
          await dequeue(op.id);
        } else {}
      }
    }

    return failedOpsSet.toList();
  }
}
