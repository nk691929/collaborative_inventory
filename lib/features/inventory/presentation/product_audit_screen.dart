import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:inventory/core/models.dart';
import 'package:inventory/features/inventory/application/inventory_manager.dart';

class ProductAudit extends ConsumerStatefulWidget {
  final Product product;
  const ProductAudit({super.key,required this.product});


  @override
  ConsumerState<ProductAudit> createState() => _ProductAuditState();
}

class _ProductAuditState extends ConsumerState<ProductAudit> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.indigo,
        foregroundColor: Colors.white,
        title: const Text('Product Audit Log'),
      ),
      body: Consumer( 
            builder: (context, watch, child) {
              final auditLogAsync = ref.watch(productAuditLogProvider(widget.product.id));

              return auditLogAsync.when(
                loading: () => const SizedBox(
                  height: 150, 
                  child: Center(child: CircularProgressIndicator())),
                
                error: (err, stack) => SizedBox(
                  height: 150,
                  child: Center(child: Text('Error loading logs: ${err.toString().split(':').last.trim()}')),
                ),
                
                data: (logs) {
                  final reversedLogs = logs.reversed.toList(); 
                  
                  if (reversedLogs.isEmpty) {
                    return const SizedBox(
                      height: 100,
                      child: Center(child: Text('No audit history available.')),
                    );
                  }

                  return SizedBox(
                    width: double.maxFinite,
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: reversedLogs.length,
                      itemBuilder: (context, index) {
                        final entry = reversedLogs[index];
                        return ListTile(
                          title: Text(entry.action, style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                          subtitle: Text('Stock: ${entry.oldStock} -> ${entry.newStock}'),
                          trailing: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                DateFormat('MM/dd HH:mm').format(entry.timestamp.toLocal()),
                                style: const TextStyle(fontSize: 12, color: Colors.grey),
                              ),
                              Text(
                                'By: ${entry.byUserEmail.split('@').first}',
                                style: const TextStyle(fontSize: 12, color: Colors.grey),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  );
                },
              );
            },
          ),
          
    );
  }
}