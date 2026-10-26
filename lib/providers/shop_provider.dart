import 'package:flutter/foundation.dart';
import '../models/shop_model.dart';
import '../models/product_model.dart';
import '../data/mock_data.dart';

class ShopProvider with ChangeNotifier {
  final List<Shop> _shops = List.from(MockData.initialShops);
  final List<Product> _products = List.from(MockData.initialProducts);

  String _searchQuery = '';
  Shop? _selectedShop;

  ShopProvider() {
    if (_shops.isNotEmpty) {
      _selectedShop = _shops.first;
    }
  }

  List<Shop> get shops {
    if (_searchQuery.isEmpty) {
      return List.unmodifiable(_shops);
    }
    return _shops.where((s) =>
      s.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
      s.address.toLowerCase().contains(_searchQuery.toLowerCase()) ||
      s.district.toLowerCase().contains(_searchQuery.toLowerCase())
    ).toList();
  }

  Shop? get selectedShop => _selectedShop;

  void selectShop(Shop shop) {
    _selectedShop = shop;
    notifyListeners();
  }

  void searchShops(String query) {
    _searchQuery = query;
    notifyListeners();
  }

  Shop? getShopById(String id) {
    try {
      return _shops.firstWhere((s) => s.id == id);
    } catch (_) {
      return null;
    }
  }

  List<Product> getProductsForShop(String shopId) {
    return _products.where((p) => p.shopId == shopId).toList();
  }

  List<Product> getServicesForShop(String shopId) {
    return _products.where((p) => p.shopId == shopId && p.isService).toList();
  }

  List<Product> getAccessoriesForShop(String shopId) {
    return _products.where((p) => p.shopId == shopId && !p.isService).toList();
  }
}
