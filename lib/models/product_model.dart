import 'package:cloud_firestore/cloud_firestore.dart';

class ProductModel {
  final String id;
  final String categoryName;
  final String name;
  final int sessionCount;
  final int unitPrice;
  final int totalPrice;
  final bool vatIncluded;
  final String lessonType;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const ProductModel({
    required this.id,
    required this.categoryName,
    required this.name,
    required this.sessionCount,
    required this.unitPrice,
    required this.totalPrice,
    required this.vatIncluded,
    required this.lessonType,
    this.createdAt,
    this.updatedAt,
  });

  factory ProductModel.fromFirestore(
      DocumentSnapshot<Map<String, dynamic>> doc,
      ) {
    final data = doc.data() ?? {};

    return ProductModel(
      id: doc.id,
      categoryName: (data['categoryName'] ?? '').toString(),
      name: (data['name'] ?? '').toString(),
      sessionCount: (data['sessionCount'] as num?)?.toInt() ?? 0,
      unitPrice: (data['unitPrice'] as num?)?.toInt() ?? 0,
      totalPrice: (data['totalPrice'] as num?)?.toInt() ?? 0,
      vatIncluded: data['vatIncluded'] as bool? ?? true,
      lessonType: (data['lessonType'] ?? 'PT').toString(),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toCreateFirestore() {
    return {
      'categoryName': categoryName.trim(),
      'name': name.trim(),
      'sessionCount': sessionCount,
      'unitPrice': unitPrice,
      'totalPrice': totalPrice,
      'vatIncluded': vatIncluded,
      'lessonType': lessonType.trim().isEmpty ? 'PT' : lessonType.trim(),
      'isDeleted': false,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  Map<String, dynamic> toUpdateFirestore() {
    return {
      'categoryName': categoryName.trim(),
      'name': name.trim(),
      'sessionCount': sessionCount,
      'unitPrice': unitPrice,
      'totalPrice': totalPrice,
      'vatIncluded': vatIncluded,
      'lessonType': lessonType.trim().isEmpty ? 'PT' : lessonType.trim(),
      'isDeleted': false,
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  Map<String, dynamic> toContractSnapshot() {
    return {
      'categoryName': categoryName,
      'name': name,
      'sessionCount': sessionCount,
      'unitPrice': unitPrice,
      'totalPrice': totalPrice,
      'vatIncluded': vatIncluded,
      'lessonType': lessonType,
    };
  }

  ProductModel copyWith({
    String? id,
    String? categoryName,
    String? name,
    int? sessionCount,
    int? unitPrice,
    int? totalPrice,
    bool? vatIncluded,
    String? lessonType,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return ProductModel(
      id: id ?? this.id,
      categoryName: categoryName ?? this.categoryName,
      name: name ?? this.name,
      sessionCount: sessionCount ?? this.sessionCount,
      unitPrice: unitPrice ?? this.unitPrice,
      totalPrice: totalPrice ?? this.totalPrice,
      vatIncluded: vatIncluded ?? this.vatIncluded,
      lessonType: lessonType ?? this.lessonType,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}