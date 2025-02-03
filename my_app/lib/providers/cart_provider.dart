import 'package:flutter/foundation.dart';
import '../models/cart.dart';

class CartProvider with ChangeNotifier {
  List<CartItem> _items = [];
  String? _currentRestaurantId;

  List<CartItem> get items => [..._items];
  
  double get totalAmount {
    return _items.fold(0, (sum, item) => sum + (item.price * item.quantity));
  }

  void addItem(CartItem item) {
    // Check if adding from a different restaurant
    if (_currentRestaurantId != null && _currentRestaurantId != item.restaurantId) {
      throw Exception('Cannot add items from different restaurants');
    }

    _currentRestaurantId = item.restaurantId;
    
    final existingIndex = _items.indexWhere((i) => i.id == item.id && i.size == item.size);
    
    if (existingIndex >= 0) {
      _items[existingIndex].quantity += 1;
    } else {
      _items.add(item);
    }
    
    notifyListeners();
  }

  void removeItem(String id, String size) {
    final index = _items.indexWhere((i) => i.id == id && i.size == size);
    if (index >= 0) {
      if (_items[index].quantity > 1) {
        _items[index].quantity -= 1;
      } else {
        _items.removeAt(index);
      }
      
      if (_items.isEmpty) {
        _currentRestaurantId = null;
      }
      
      notifyListeners();
    }
  }

  void clearCart() {
    _items = [];
    _currentRestaurantId = null;
    notifyListeners();
  }
} 