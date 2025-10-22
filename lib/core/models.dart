import 'package:hive/hive.dart';
import 'package:uuid/uuid.dart';
part 'models.g.dart'; 

@HiveType(typeId: 0)
enum AppRole {
  @HiveField(0)
  admin, 
  @HiveField(1)
  manager,
  @HiveField(2)
  viewer,
  @HiveField(3)
  unauthenticated,
}

//user model
@HiveType(typeId: 1)
class AppUser {
  @HiveField(0)
  final String id;
  @HiveField(1)
  final String email;
  @HiveField(2)
  final AppRole role;

  AppUser({required this.id, required this.email, required this.role});

  AppUser copyWith({String? id, String? email, AppRole? role}) {
    return AppUser(
      id: id ?? this.id,
      email: email ?? this.email,
      role: role ?? this.role,
    );
  }
}

//product model
@HiveType(typeId: 2)
class Product {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String name;

  @HiveField(2)
  final int stock;

  @HiveField(3)
  final DateTime lastUpdated;

  @HiveField(4)
  final List<ProductAuditEntry> auditLog;

  @HiveField(5, defaultValue: true)
  final bool isSynced;

  bool isPending = false;

  Product({
    String? id,
    required this.name,
    required this.stock,
    DateTime? lastUpdated,
    List<ProductAuditEntry>? auditLog,
    this.isSynced = true,
  }) : id = id ?? const Uuid().v4(),
       lastUpdated = lastUpdated ?? DateTime.now(),
       auditLog = auditLog ?? const [];

  Product copyWith({
    String? id,
    String? name,
    int? stock,
    DateTime? lastUpdated,
    List<ProductAuditEntry>? auditLog,
    bool? isSynced,
    bool? isPending,
  }) {
    final newProduct = Product(
      id: id ?? this.id,
      name: name ?? this.name,
      stock: stock ?? this.stock,
      lastUpdated: lastUpdated ?? this.lastUpdated,
      auditLog: auditLog ?? this.auditLog,
      isSynced: isSynced ?? this.isSynced,
    );
    newProduct.isPending = isPending ?? this.isPending;
    return newProduct;
  }
}

//product audit entry model
@HiveType(typeId: 3)
class ProductAuditEntry {
  @HiveField(0)
  final String productId; 
  @HiveField(1)
  final DateTime timestamp;
  @HiveField(2)
  final String action;
  @HiveField(3)
  final String byUserEmail;
  @HiveField(4)
  final int oldStock;
  @HiveField(5)
  final int newStock;

  ProductAuditEntry({
    required this.productId,
    required this.timestamp,
    required this.action,
    required this.byUserEmail,
    required this.oldStock,
    required this.newStock,
  });

  ProductAuditEntry copyWith({
    String? productId,
    DateTime? timestamp,
    String? action,
    String? byUserEmail,
    int? oldStock,
    int? newStock,
  }) {
    return ProductAuditEntry(
      productId: productId ?? this.productId,
      timestamp: timestamp ?? this.timestamp,
      action: action ?? this.action,
      byUserEmail: byUserEmail ?? this.byUserEmail,
      oldStock: oldStock ?? this.oldStock,
      newStock: newStock ?? this.newStock,
    );
  }
}

//offline operation model
@HiveType(typeId: 4)
class OfflineOperation {
  @HiveField(0)
  final String id;
  @HiveField(1)
  final OperationType type;
  @HiveField(2)
  final String targetProductId; 
  @HiveField(3)
  final int stockChange; 
  @HiveField(4)
  final String payloadJson; 
  @HiveField(5)
  final DateTime queuedAt;
  @HiveField(6)
  int retryCount;

  OfflineOperation({
    String? id,
    required this.type,
    required this.targetProductId,
    this.stockChange = 0,
    this.payloadJson = '',
    DateTime? queuedAt,
    this.retryCount = 0,
  }) : id = id ?? const Uuid().v4(),
       queuedAt = queuedAt ?? DateTime.now();

  OfflineOperation copyWith({
    String? id,
    OperationType? type,
    String? targetProductId,
    int? stockChange,
    String? payloadJson,
    DateTime? queuedAt,
    int? retryCount,
  }) {
    return OfflineOperation(
      id: id ?? this.id,
      type: type ?? this.type,
      targetProductId: targetProductId ?? this.targetProductId,
      stockChange: stockChange ?? this.stockChange,
      payloadJson: payloadJson ?? this.payloadJson,
      queuedAt: queuedAt ?? this.queuedAt,
      retryCount: retryCount ?? this.retryCount,
    );
  }
}

//action performed in the operation queue.
@HiveType(typeId: 5)
enum OperationType {
  @HiveField(0)
  createProduct,
  @HiveField(1)
  updateStock,
  @HiveField(2)
  deleteProduct,
  @HiveField(3)
  updateUserRole,
}
