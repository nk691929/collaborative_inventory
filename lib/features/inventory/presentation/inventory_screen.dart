import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:inventory/features/inventory/presentation/widget/product_tile.dart';
import '../../../../core/connectivity_service.dart';
import '../../../../core/models.dart';
import '../../auth/application/auth_notifier.dart';
import '../../auth/presentation/login_screen.dart';
import '../application/inventory_manager.dart';
import '../application/offline_queue_service.dart';

class InventoryScreen extends ConsumerWidget {
  const InventoryScreen({super.key});

  void _showAddProductDialog(BuildContext context, WidgetRef ref) {
    final nameController = TextEditingController();
    final stockController = TextEditingController(text: '10');
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Add New Product'),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: nameController,
                  decoration: const InputDecoration(labelText: 'Product Name'),
                  validator: (v) => v!.isEmpty ? 'Required' : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: stockController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Initial Stock'),
                  validator: (v) =>
                      int.tryParse(v ?? '') == null || int.parse(v!) < 0
                      ? 'Must be a non-negative number'
                      : null,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                if (formKey.currentState!.validate()) {
                  ref
                      .read(inventoryManagerProvider.notifier)
                      .createProduct(
                        nameController.text,
                        int.parse(stockController.text),
                      );
                  Navigator.pop(context);
                }
              },
              child: const Text('Add'),
            ),
          ],
        );
      },
    );
  }

  void _showQueueFailedDialog(
    BuildContext context,
    WidgetRef ref,
    List<OfflineOperation> failedOps,
  ) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Offline Sync Failed'),
          content: SizedBox(
            width: double.maxFinite,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Could not synchronize ${failedOps.length} operation(s) due to possible conflicts or server errors.',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                const Text(
                  'Please choose to retry or discard the following failed edits:',
                ),
                const SizedBox(height: 12),
                Flexible(
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: failedOps.length,
                    itemBuilder: (context, index) {
                      final op = failedOps[index];
                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          title: Text(op.type.name.toUpperCase()),
                          subtitle: Text(
                            'Product ID: ${op.targetProductId}\nStock Delta: ${op.stockChange}\nRetries: ${op.retryCount}',
                            style: const TextStyle(fontSize: 12),
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              TextButton(
                                onPressed: () {
                                  Navigator.pop(context);
                                  ref
                                      .read(inventoryManagerProvider.notifier)
                                      .handleOnlineTransition();
                                },
                                child: const Text('RETRY'),
                              ),
                              TextButton(
                                onPressed: () {
                                  ref
                                      .read(inventoryManagerProvider.notifier)
                                      .discardOperation(op.id);
                                  Navigator.pop(context);
                                },
                                style: TextButton.styleFrom(
                                  foregroundColor: Colors.red,
                                ),
                                child: const Text('DISCARD'),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final products = ref.watch(inventoryManagerProvider);
    final user = ref.watch(authProvider);
    final canCreate = ref.watch(permissionProvider(AppRole.manager));
    final isOnline = ref.watch(isOnlineProvider).value ?? false;
    final offlineQueue = ref.watch(offlineQueueProvider);

    final failedOps = offlineQueue.where((op) => op.retryCount > 0).toList();
    if (failedOps.isNotEmpty && isOnline) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _showQueueFailedDialog(context, ref, failedOps);
      });
    }

    if (user == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => const LoginScreen()),
        );
      });
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Inventory'),
        backgroundColor: Colors.indigo,
        foregroundColor: Colors.white,
        actions: [
          Tooltip(
            message: isOnline ? 'Online' : 'Offline',
            child: Icon(
              isOnline ? Icons.wifi : Icons.wifi_off,
              color: isOnline ? Colors.greenAccent : Colors.redAccent,
            ),
          ),
          const SizedBox(width: 8),

          if (offlineQueue.isNotEmpty)
            Tooltip(
              message: '${offlineQueue.length} total operations queued.',
              child: Stack(
                children: [
                  IconButton(
                    icon: const Icon(
                      Icons.cloud_upload,
                      color: Colors.yellowAccent,
                    ),
                    onPressed: () {
                      if (failedOps.isNotEmpty) {
                        _showQueueFailedDialog(context, ref, failedOps);
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'Queue is actively waiting for network recovery.',
                            ),
                          ),
                        );
                      }
                    },
                  ),
                  Positioned(
                    right: 0,
                    child: CircleAvatar(
                      radius: 8,
                      backgroundColor: Colors.red,
                      child: Text(
                        '${offlineQueue.length}',
                        style: const TextStyle(
                          fontSize: 9,
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(width: 8),

          Center(
            child: Padding(
              padding: const EdgeInsets.only(right: 8.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    user.role.name.toUpperCase(),
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    user.email.split('@').first,
                    style: const TextStyle(fontSize: 10),
                  ),
                ],
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await ref.read(authProvider.notifier).logout();
              if (context.mounted) {
                Navigator.of(context).pushReplacement(
                  MaterialPageRoute(builder: (context) => const LoginScreen()),
                );
              }
            },
          ),
        ],
      ),

      body: RefreshIndicator(
        onRefresh: () =>
            ref.read(inventoryManagerProvider.notifier).fetchProducts(),
        child:
            products.isEmpty &&
                !canCreate
            ? Center(
                child: Text(
                  'No products found.',
                  style: TextStyle(fontSize: 18, color: Colors.grey.shade600),
                ),
              )
            : products.isEmpty &&
                  canCreate 
            ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'No products found.',
                      style: TextStyle(
                        fontSize: 18,
                        color: Colors.grey.shade600,
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: ElevatedButton.icon(
                        onPressed: () => _showAddProductDialog(context, ref),
                        icon: const Icon(Icons.add),
                        label: const Text('Add First Product'),
                      ),
                    ),
                  ],
                ),
              )
            : ListView.builder(
                itemCount: products.length,
                itemBuilder: (context, index) {
                  return ProductTile(product: products[index]);
                },
              ),
      ),

      floatingActionButton: canCreate
          ? FloatingActionButton.extended(
              onPressed: () => _showAddProductDialog(context, ref),
              label: const Text('Add Product'),
              icon: const Icon(Icons.add),
              backgroundColor: Colors.indigo,
              foregroundColor: Colors.white,
            )
          : null,
    );
  }
}
