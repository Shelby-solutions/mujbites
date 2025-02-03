class CartItem {
  final String id;
  final String name;
  final double price;
  final String size;
  final String restaurantId;
  final String restaurantName; // Add this field
  int quantity;

  CartItem({
    required this.id,
    required this.name,
    required this.price,
    required this.size,
    required this.restaurantId,
    required this.restaurantName, // Add this parameter
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
      'restaurantName': restaurantName, // Add this field
    };
  }

  factory CartItem.fromJson(Map<String, dynamic> json) {
    return CartItem(
      id: json['id'],
      name: json['name'],
      price: json['price'].toDouble(),
      size: json['size'],
      restaurantId: json['restaurantId'],
      restaurantName: json['restaurantName'], // Add this field
      quantity: json['quantity'],
    );
  }
}