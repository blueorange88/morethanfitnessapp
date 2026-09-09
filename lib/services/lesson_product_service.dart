import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/product_model.dart';

class LessonProductService {
  static final _col =
  FirebaseFirestore.instance.collection('lesson_products');

  static Stream<List<ProductModel>> watchProducts() {
    return _col.snapshots().map((snapshot) {
      final products = snapshot.docs
          .where((doc) {
        final data = doc.data();
        return data['isDeleted'] != true;
      })
          .map((doc) => ProductModel.fromFirestore(doc))
          .toList();

      products.sort((a, b) {
        final aDate = a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        final bDate = b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        return aDate.compareTo(bDate);
      });

      return products;
    });
  }

  static Future<List<ProductModel>> fetchProducts() async {
    final snapshot = await _col.get();

    final products = snapshot.docs
        .where((doc) {
      final data = doc.data();
      return data['isDeleted'] != true;
    })
        .map((doc) => ProductModel.fromFirestore(doc))
        .toList();

    products.sort((a, b) {
      final aDate = a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      final bDate = b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      return bDate.compareTo(aDate);
    });

    return products;
  }

  static Future<void> addProduct(ProductModel product) async {
    final docRef = _col.doc();

    await docRef.set({
      ...product.toCreateFirestore(),
      'id': docRef.id,
      'isDeleted': false,
    });
  }

  static Future<void> updateProduct(ProductModel product) async {
    await _col.doc(product.id).set({
      ...product.toUpdateFirestore(),
      'id': product.id,
      'isDeleted': false,
    }, SetOptions(merge: true));
  }

  static Future<void> deleteProduct(String id) async {
    await _col.doc(id).set({
      'isDeleted': true,
      'deletedAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }
}