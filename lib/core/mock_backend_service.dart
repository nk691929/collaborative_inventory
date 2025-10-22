import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'models.dart';

final mockBackendServiceProvider = Provider<MockBackendService>((ref) {
  throw UnimplementedError(
    'MockBackendService must be provided via an override in the root ProviderScope, '
    'initialized with an opened Box<Product> and Box<ProductAuditEntry>.',
  );
});

class MockBackendService {
  final Box<Product> _productBox;
  final Box<ProductAuditEntry> _auditBox;
  final Map<String, DateTime> _serverTimestamps = {};
  final List<Product> _backendProducts = [];
  bool _isOnline = true;
  bool get isOnline => _isOnline;

  MockBackendService(this._productBox, this._auditBox) {
    for (var product in _productBox.values) {
      _serverTimestamps[product.id] = product.lastUpdated;
      _backendProducts.add(product);
    }
  }

  void setOnline(bool status) {
    _isOnline = status;
    debugPrint('Connectivity status manually set to: $_isOnline');
  }

  Future<List<Product>> fetchProducts() async {
    await Future.delayed(const Duration(milliseconds: 300));

    try {
      final localProducts = _productBox.values.toList();

      if (!_isOnline) {
        debugPrint('Offline: returning ${localProducts.length} products from Hive.');
        return localProducts;
      }

      if (_backendProducts.isEmpty && localProducts.isNotEmpty) {
        _backendProducts.addAll(localProducts);
      }

      for (final product in _backendProducts) {
        await _productBox.put(product.id, product);
      }

      final allProducts = {
        for (final p in _productBox.values) p.id: p,
      }.values.toList();

      debugPrint('MockBackend: Fetched ${allProducts.length} products from Hive.');
      debugPrint('Products successfully fetched and cached.');
      return allProducts;
    } catch (e) {
      debugPrint('Error in fetchProducts(): $e');
      rethrow;
    }
  }

  Future<List<ProductAuditEntry>> fetchAuditHistory(String productId) async {
    await Future.delayed(const Duration(milliseconds: 200));
    final history = _auditBox.values
        .where((entry) {
          try {
            return entry.productId == productId;
          } catch (_) {
            return false;
          }
        })
        .toList()
      ..sort((a, b) => b.timestamp.compareTo(a.timestamp));

    debugPrint('MockBackend: Returning ${history.length} audit entries for product $productId.');
    return history;
  }

  Future<Product> updateStock({
    required String productId,
    required int newStock,
    required String userEmail,
    required DateTime clientTimestamp,
  }) async {
    await Future.delayed(const Duration(milliseconds: 400));

    final existingProduct = _productBox.get(productId);
    if (existingProduct == null) {
      throw Exception('NOT_FOUND: Product $productId not found.');
    }

    final serverTimestamp = _serverTimestamps[productId];
    if (serverTimestamp != null && clientTimestamp.isBefore(serverTimestamp)) {
      throw Exception('CONFILCT_409: Update rejected due to LWW conflict.');
    }

    final oldStockValue = existingProduct.stock;

    final updatedProduct = existingProduct.copyWith(
      stock: newStock,
      lastUpdated: DateTime.now(),
    );

    _updateBackendProduct(updatedProduct);
    await _productBox.put(updatedProduct.id, updatedProduct);

    _serverTimestamps[productId] = updatedProduct.lastUpdated;

    await _auditBox.add(
      ProductAuditEntry(
        productId: productId,
        timestamp: DateTime.now(),
        byUserEmail: userEmail,
        action: 'STOCK_UPDATE',
        oldStock: oldStockValue,
        newStock: newStock,
      ),
    );

    debugPrint('MockBackend: Stock updated for $productId to $newStock by $userEmail');
    return updatedProduct;
  }

  Future<Product> createProduct(Product product, String userEmail) async {
  await Future.delayed(const Duration(milliseconds: 700));

  if (product.id.startsWith('p')) {
    return product; 
  }

  final serverId = 'p${Random().nextInt(99999).toString().padLeft(5, '0')}';
  
  final newProduct = product.copyWith(
    id: serverId,
    lastUpdated: DateTime.now(),
    isSynced: true,
  );

  await _productBox.put(serverId, newProduct);
  await _auditBox.add(ProductAuditEntry(
    productId: serverId,
    timestamp: DateTime.now(),
    byUserEmail: userEmail,
    action: 'PRODUCT_CREATED',
    oldStock: 0,
    newStock: newProduct.stock,
  ));

  debugPrint('MockBackend: Synced product ${product.name} -> $serverId');
  return newProduct;
}


  Future<void> deleteProduct(String productId, String userEmail) async {
    await Future.delayed(const Duration(milliseconds: 500));

    final initialProduct = _productBox.get(productId);
    if (initialProduct == null) {
      throw Exception('NOT_FOUND: Product $productId not found for deletion.');
    }

    _backendProducts.removeWhere((p) => p.id == productId);
    await _productBox.delete(productId);
    _serverTimestamps.remove(productId);

    await _auditBox.add(
      ProductAuditEntry(
        productId: productId,
        timestamp: DateTime.now(),
        byUserEmail: userEmail,
        action: 'PRODUCT_DELETED',
        oldStock: initialProduct.stock,
        newStock: 0,
      ),
    );

    debugPrint('MockBackend: Product $productId deleted.');
  }

  Future<void> syncOfflineProducts(String userEmail) async {
    final unsynced = _productBox.values.where((p) => p.isSynced == false).toList();

    for (final localProduct in unsynced) {
      try {
        final serverProduct = await createProduct(localProduct, userEmail);
        await _productBox.delete(localProduct.id);
        await _productBox.put(
          serverProduct.id,
          serverProduct.copyWith(isSynced: true),
        );

        debugPrint('Synced offline product: ${localProduct.name}');
      } catch (e) {
        debugPrint('Failed to sync offline product ${localProduct.name}: $e');
      }
    }
  }

  void _updateBackendProduct(Product updatedProduct) {
    final index = _backendProducts.indexWhere((p) => p.id == updatedProduct.id);
    if (index != -1) {
      _backendProducts[index] = updatedProduct;
    } else {
      _backendProducts.add(updatedProduct);
    }
  }
}
