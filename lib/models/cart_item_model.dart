import 'product_model.dart';
import 'racket_model.dart';

class CartItem {
  final String id;
  final Product product;
  int quantity;
  Racket? targetRacket; // Optional: The racket assigned to be strung
  double? requestedTensionLbs;
  String stringingTechnique; // "4 nút chuẩn Yonex" or "2 nút"
  String selectedColor;
  String specialNotes;

  CartItem({
    required this.id,
    required this.product,
    this.quantity = 1,
    this.targetRacket,
    this.requestedTensionLbs,
    this.stringingTechnique = '4 nút chuẩn Yonex',
    this.selectedColor = 'Trắng',
    this.specialNotes = '',
  });

  double get totalPrice => product.price * quantity;
}
