// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'models.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class AppUserAdapter extends TypeAdapter<AppUser> {
  @override
  final int typeId = 1;

  @override
  AppUser read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return AppUser(
      id: fields[0] as String,
      email: fields[1] as String,
      role: fields[2] as AppRole,
    );
  }

  @override
  void write(BinaryWriter writer, AppUser obj) {
    writer
      ..writeByte(3)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.email)
      ..writeByte(2)
      ..write(obj.role);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AppUserAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class ProductAdapter extends TypeAdapter<Product> {
  @override
  final int typeId = 2;

  @override
  Product read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Product(
      id: fields[0] as String?,
      name: fields[1] as String,
      stock: fields[2] as int,
      lastUpdated: fields[3] as DateTime?,
      auditLog: (fields[4] as List?)?.cast<ProductAuditEntry>(),
      isSynced: fields[5] == null ? true : fields[5] as bool,
    );
  }

  @override
  void write(BinaryWriter writer, Product obj) {
    writer
      ..writeByte(6)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.name)
      ..writeByte(2)
      ..write(obj.stock)
      ..writeByte(3)
      ..write(obj.lastUpdated)
      ..writeByte(4)
      ..write(obj.auditLog)
      ..writeByte(5)
      ..write(obj.isSynced);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ProductAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class ProductAuditEntryAdapter extends TypeAdapter<ProductAuditEntry> {
  @override
  final int typeId = 3;

  @override
  ProductAuditEntry read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return ProductAuditEntry(
      productId: fields[0] as String,
      timestamp: fields[1] as DateTime,
      action: fields[2] as String,
      byUserEmail: fields[3] as String,
      oldStock: fields[4] as int,
      newStock: fields[5] as int,
    );
  }

  @override
  void write(BinaryWriter writer, ProductAuditEntry obj) {
    writer
      ..writeByte(6)
      ..writeByte(0)
      ..write(obj.productId)
      ..writeByte(1)
      ..write(obj.timestamp)
      ..writeByte(2)
      ..write(obj.action)
      ..writeByte(3)
      ..write(obj.byUserEmail)
      ..writeByte(4)
      ..write(obj.oldStock)
      ..writeByte(5)
      ..write(obj.newStock);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ProductAuditEntryAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class OfflineOperationAdapter extends TypeAdapter<OfflineOperation> {
  @override
  final int typeId = 4;

  @override
  OfflineOperation read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return OfflineOperation(
      id: fields[0] as String?,
      type: fields[1] as OperationType,
      targetProductId: fields[2] as String,
      stockChange: fields[3] as int,
      payloadJson: fields[4] as String,
      queuedAt: fields[5] as DateTime?,
      retryCount: fields[6] as int,
    );
  }

  @override
  void write(BinaryWriter writer, OfflineOperation obj) {
    writer
      ..writeByte(7)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.type)
      ..writeByte(2)
      ..write(obj.targetProductId)
      ..writeByte(3)
      ..write(obj.stockChange)
      ..writeByte(4)
      ..write(obj.payloadJson)
      ..writeByte(5)
      ..write(obj.queuedAt)
      ..writeByte(6)
      ..write(obj.retryCount);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is OfflineOperationAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class AppRoleAdapter extends TypeAdapter<AppRole> {
  @override
  final int typeId = 0;

  @override
  AppRole read(BinaryReader reader) {
    switch (reader.readByte()) {
      case 0:
        return AppRole.admin;
      case 1:
        return AppRole.manager;
      case 2:
        return AppRole.viewer;
      case 3:
        return AppRole.unauthenticated;
      default:
        return AppRole.admin;
    }
  }

  @override
  void write(BinaryWriter writer, AppRole obj) {
    switch (obj) {
      case AppRole.admin:
        writer.writeByte(0);
        break;
      case AppRole.manager:
        writer.writeByte(1);
        break;
      case AppRole.viewer:
        writer.writeByte(2);
        break;
      case AppRole.unauthenticated:
        writer.writeByte(3);
        break;
    }
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AppRoleAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class OperationTypeAdapter extends TypeAdapter<OperationType> {
  @override
  final int typeId = 5;

  @override
  OperationType read(BinaryReader reader) {
    switch (reader.readByte()) {
      case 0:
        return OperationType.createProduct;
      case 1:
        return OperationType.updateStock;
      case 2:
        return OperationType.deleteProduct;
      case 3:
        return OperationType.updateUserRole;
      default:
        return OperationType.createProduct;
    }
  }

  @override
  void write(BinaryWriter writer, OperationType obj) {
    switch (obj) {
      case OperationType.createProduct:
        writer.writeByte(0);
        break;
      case OperationType.updateStock:
        writer.writeByte(1);
        break;
      case OperationType.deleteProduct:
        writer.writeByte(2);
        break;
      case OperationType.updateUserRole:
        writer.writeByte(3);
        break;
    }
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is OperationTypeAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
