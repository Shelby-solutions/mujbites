class CartItem {
  final String id;
  final String name;
  final double price;
  final String size;
  final String restaurantId;
  final String restaurantName;
  int quantity;

  CartItem({
    required this.id,
    required this.name,
    required this.price,
    required this.size,
    required this.restaurantId,
    required this.restaurantName,
    this.quantity = 1,
  });

  Map<String, dynamic> toJson() {
    return {
      'menuItem': id,
      'itemName': name,
      'price': price,
      'size': size,
      'quantity': quantity,
      'restaurantId': restaurantId,
      'restaurantName': restaurantName,
    };
  }

  factory CartItem.fromJson(Map<String, dynamic> json) {
    return CartItem(
      id: json['menuItem'] ?? json['id'],
      name: json['itemName'] ?? json['name'],
      price: (json['price'] is int) 
          ? json['price'].toDouble() 
          : json['price'].toDouble(),
      size: json['size'],
      restaurantId: json['restaurantId'],
      restaurantName: json['restaurantName'],
      quantity: json['quantity'] ?? 1,
    );
  }

  CartItem copyWith({
    String? id,
    String? name,
    double? price,
    String? size,
    String? restaurantId,
    String? restaurantName,
    int? quantity,
  }) {
    return CartItem(
      id: id ?? this.id,
      name: name ?? this.name,
      price: price ?? this.price,
      size: size ?? this.size,
      restaurantId: restaurantId ?? this.restaurantId,
      restaurantName: restaurantName ?? this.restaurantName,
      quantity: quantity ?? this.quantity,
    );
  }
}

class Cart {
  final String userId;
  final List<CartItem> items;
  final DateTime lastUpdated;

  Cart({
    required this.userId,
    List<CartItem>? items,
    DateTime? lastUpdated,
  }) : 
    this.items = items ?? [],
    this.lastUpdated = lastUpdated ?? DateTime.now();

  double get totalAmount => items.fold(
    0, 
    (total, item) => total + (item.price * item.quantity)
  );

  Map<String, dynamic> toJson() {
    return {
      'userId': userId,
      'items': items.map((item) => item.toJson()).toList(),
      'lastUpdated': lastUpdated.toIso8601String(),
    };
  }

  factory Cart.fromJson(Map<String, dynamic> json) {
    return Cart(
      userId: json['userId'],
      items: (json['items'] as List?)
          ?.map((item) => CartItem.fromJson(item))
          .toList() ?? [],
      lastUpdated: json['lastUpdated'] != null 
          ? DateTime.parse(json['lastUpdated'])
          : DateTime.now(),
    );
  }

  Cart copyWith({
    String? userId,
    List<CartItem>? items,
    DateTime? lastUpdated,
  }) {
    return Cart(
      userId: userId ?? this.userId,
      items: items ?? this.items,
      lastUpdated: lastUpdated ?? this.lastUpdated,
    );
  }
} 