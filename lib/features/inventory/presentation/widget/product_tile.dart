import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:inventory/features/inventory/presentation/product_audit_screen.dart';
import '../../../../../core/models.dart';
import '../../../auth/application/auth_notifier.dart';
import '../../application/inventory_manager.dart';



class ProductTile extends ConsumerWidget {
  final Product product;
  const ProductTile({super.key, required this.product});

  void _confirmDelete(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Confirm Deletion'),
          content: Text('Are you sure you want to delete "${product.name}"? This action cannot be undone.'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () {
                ref.read(inventoryManagerProvider.notifier).deleteProduct(product.id);
                Navigator.pop(context);
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
              child: const Text('DELETE'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final canEdit = ref.watch(permissionProvider(AppRole.manager));
    final isAdmin = ref.watch(permissionProvider(AppRole.admin));
    final isQueued = ref.watch(isProductQueuedProvider(product.id));

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12.0), 
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    product.name,
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    overflow: TextOverflow.ellipsis, 
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Last Updated: ${DateFormat('MM/dd HH:mm:ss').format(product.lastUpdated.toLocal())}',
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ],
              ),
            ),
            
            const SizedBox(width: 8), 
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (product.isPending)
                  const Padding(
                    padding: EdgeInsets.only(right: 4.0),
                    child: Tooltip(
                      message: 'Optimistic Update Pending...',
                      child: Icon(Icons.sync, color: Colors.orange, size: 20),
                    ),
                  )
                else if (isQueued)
                  const Padding(
                    padding: EdgeInsets.only(right: 4.0),
                    child: Tooltip(
                      message: 'Offline operation queued.',
                      child: Icon(Icons.cloud_off, color: Colors.red, size: 20),
                    ),
                  ),

                SizedBox( 
                  width: 36, 
                  child: Text(
                    '${product.stock}',
                    textAlign: TextAlign.right,
                    style: TextStyle(
                      fontSize: 20, 
                      fontWeight: FontWeight.w900,
                      color: product.stock <= 5 ? Colors.red.shade700 : Colors.indigo,
                    ),
                  ),
                ),
                
                IconButton(
                  icon: const Icon(Icons.history, color: Colors.grey, size: 20),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  onPressed: () {
                    Navigator.push(context, MaterialPageRoute(builder: (context) => ProductAudit(product: product)));
                  }, 
                ),
                
                if (isAdmin)
                  IconButton(
                    icon: const Icon(Icons.delete, color: Colors.red, size: 20),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    onPressed: () => _confirmDelete(context, ref),
                  ),

                if (canEdit && !product.isPending)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.remove_circle_outline, color: Colors.red, size: 20),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        onPressed: () {
                          ref.read(inventoryManagerProvider.notifier).updateStock(product.id, -1);
                        },
                      ),
                      IconButton(
                        icon: const Icon(Icons.add_circle_outline, color: Colors.green, size: 20),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        onPressed: () {
                          ref.read(inventoryManagerProvider.notifier).updateStock(product.id, 1);
                        },
                      ),
                    ],
                  )
                else if (canEdit && product.isPending)
                  const SizedBox(width: 50, child: Center(child: Text('Syncing...', style: TextStyle(fontSize: 10))))
              ],
            ),
          ],
        ),
      ),
    );
  }
}
