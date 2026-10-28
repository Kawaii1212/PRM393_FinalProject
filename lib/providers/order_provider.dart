import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/order_model.dart';

class OrderProvider with ChangeNotifier {
  static const String _prefOrdersKey = 'gearsports_orders_cache';

  List<OrderModel> _orders = [];
  bool _isLoading = false;

  List<OrderModel> get orders => List.unmodifiable(_orders);
  bool get isLoading => _isLoading;

  OrderProvider() {
    loadOrders();
  }

  bool get _isFirebaseReady {
    try {
      return Firebase.apps.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  Future<void> loadOrders() async {
    _isLoading = true;
    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();
      final cachedStr = prefs.getString(_prefOrdersKey);
      if (cachedStr != null && cachedStr.isNotEmpty) {
        final list = jsonDecode(cachedStr) as List<dynamic>;
        _orders = list
            .map((e) => OrderModel.fromMap(Map<String, dynamic>.from(e)))
            .toList();
      }

      if (_isFirebaseReady) {
        final snap = await FirebaseFirestore.instance
            .collection('orders')
            .orderBy('createdAt', descending: true)
            .get()
            .timeout(const Duration(seconds: 6));

        if (snap.docs.isNotEmpty) {
          final remoteList = snap.docs
              .map((d) => OrderModel.fromMap(d.data(), docId: d.id))
              .toList();

          final mapById = <String, OrderModel>{};
          for (final o in _orders) {
            mapById[o.id] = o;
          }
          for (final o in remoteList) {
            mapById[o.id] = o;
          }
          _orders = mapById.values.toList()
            ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

          await prefs.setString(
            _prefOrdersKey,
            jsonEncode(_orders.map((o) => o.toMap()).toList()),
          );
        }
      }
    } catch (e) {
      debugPrint('OrderProvider loadOrders error: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  List<OrderModel> getOrdersForShop(String shopId) {
    return _orders.where((o) => o.shopId == shopId).toList();
  }

  List<OrderModel> getOrdersForCustomer(String customerUid) {
    return _orders.where((o) => o.customerId == customerUid).toList();
  }

  int getPendingCountForShop(String shopId) {
    return getOrdersForShop(shopId)
        .where((o) => o.status == OrderStatus.pending || o.status == OrderStatus.stringing)
        .length;
  }

  double getRevenueForShop(String shopId) {
    return getOrdersForShop(shopId)
        .where((o) => o.status == OrderStatus.completed)
        .fold(0.0, (acc, o) => acc + o.totalAmount);
  }

  Future<void> createOrder(OrderModel order) async {
    _orders.insert(0, order);
    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _prefOrdersKey,
        jsonEncode(_orders.map((o) => o.toMap()).toList()),
      );

      if (_isFirebaseReady) {
        await FirebaseFirestore.instance
            .collection('orders')
            .doc(order.id)
            .set(order.toMap(), SetOptions(merge: true))
            .timeout(const Duration(seconds: 5));
      }
    } catch (e) {
      debugPrint('createOrder error: $e');
    }
  }

  Future<void> updateOrderStatus(String orderId, OrderStatus newStatus) async {
    final idx = _orders.indexWhere((o) => o.id == orderId);
    if (idx != -1) {
      _orders[idx] = _orders[idx].copyWith(status: newStatus);
      notifyListeners();

      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(
          _prefOrdersKey,
          jsonEncode(_orders.map((o) => o.toMap()).toList()),
        );

        if (_isFirebaseReady) {
          await FirebaseFirestore.instance
              .collection('orders')
              .doc(orderId)
              .update({'status': newStatus.name})
              .timeout(const Duration(seconds: 5));
        }
      } catch (e) {
        debugPrint('updateOrderStatus error: $e');
      }
    }
  }
}
