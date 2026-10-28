import 'package:flutter/foundation.dart';
import '../models/cart_item_model.dart';
import '../models/product_model.dart';
import '../models/racket_model.dart';

class CartProvider with ChangeNotifier {
  final List<CartItem> _items = [];

  List<CartItem> get items => List.unmodifiable(_items);

  int get itemCount {
    return _items.fold(0, (sum, item) => sum + item.quantity);
  }

  double get subtotal {
    return _items.fold(0.0, (sum, item) => sum + item.totalPrice);
  }

  // Delivery or service fee
  double get serviceFee => _items.any((item) => item.product.isService) ? 10000.0 : 0.0;

  double get totalAmount => subtotal + serviceFee;

  bool get hasService => _items.any((item) => item.product.isService);

  void addToCart(
    Product product, {
    int quantity = 1,
    Racket? targetRacket,
    double? requestedTensionLbs,
    String stringingTechnique = '4 nút chuẩn Yonex',
    String selectedColor = 'Trắng',
    String specialNotes = '',
  }) {
    // If it's a stringing service for a specific racket, keep as unique line
    if (product.isService) {
      _items.add(
        CartItem(
          id: 'cart_${DateTime.now().millisecondsSinceEpoch}',
          product: product,
          quantity: quantity,
          targetRacket: targetRacket,
          requestedTensionLbs: requestedTensionLbs,
          stringingTechnique: stringingTechnique,
          selectedColor: selectedColor,
          specialNotes: specialNotes,
        ),
      );
    } else {
      // If same physical product exists with same color, increment qty
      final index = _items.indexWhere(
        (item) => item.product.id == product.id && item.selectedColor == selectedColor,
      );
      if (index != -1) {
        _items[index].quantity += quantity;
      } else {
        _items.add(
          CartItem(
            id: 'cart_${DateTime.now().millisecondsSinceEpoch}',
            product: product,
            quantity: quantity,
            selectedColor: selectedColor,
            specialNotes: specialNotes,
          ),
        );
      }
    }
    notifyListeners();
  }

  void updateQuantity(String itemId, int qty) {
    final index = _items.indexWhere((i) => i.id == itemId);
    if (index != -1) {
      if (qty <= 0) {
        _items.removeAt(index);
      } else {
        _items[index].quantity = qty;
      }
      notifyListeners();
    }
  }

  void removeItem(String itemId) {
    _items.removeWhere((i) => i.id == itemId);
    notifyListeners();
  }

  void clearCart() {
    _items.clear();
    notifyListeners();
  }
}
