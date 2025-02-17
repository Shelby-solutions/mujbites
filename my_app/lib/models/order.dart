import 'package:my_app/models/cart.dart';

class OrderItem {
  final String menuItem;
  final String itemName;
  final int quantity;
  final String size;
  final double price;

  OrderItem({
    required this.menuItem,
    required this.itemName,
    required this.quantity,
    required this.size,
    required this.price,
  });

  factory OrderItem.fromJson(Map<String, dynamic> json) {
    return OrderItem(
      menuItem: json['menuItem'] ?? '',
      itemName: json['itemName'] ?? '',
      quantity: json['quantity'] ?? 0,
      size: json['size'] ?? '',
      price: (json['price'] ?? 0.0).toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'menuItem': menuItem,
      'itemName': itemName,
      'quantity': quantity,
      'size': size,
      'price': price,
    };
  }

  factory OrderItem.fromCartItem(CartItem item) => OrderItem(
    menuItem: item.id,
    itemName: item.name,
    quantity: item.quantity,
    size: item.size,
    price: item.price,
  );
}

class Order {
  final String id;
  final String restaurantId;
  final String restaurantName;
  final String customerId;
  final List<OrderItem> items;
  final double totalAmount;
  final String status;
  final String? cancellationReason;
  final String address;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String platform;

  Order({
    required this.id,
    required this.restaurantId,
    required this.restaurantName,
    required this.customerId,
    required this.items,
    required this.totalAmount,
    required this.status,
    this.cancellationReason,
    required this.address,
    required this.createdAt,
    required this.updatedAt,
    required this.platform,
  });

  factory Order.fromJson(Map<String, dynamic> json) {
    return Order(
      id: json['_id'] ?? '',
      restaurantId: json['restaurant'] ?? '',
      restaurantName: json['restaurantName'] ?? '',
      customerId: json['customer'] ?? '',
      items: (json['items'] as List<dynamic>?)
          ?.map((item) => OrderItem.fromJson(item))
          .toList() ?? [],
      totalAmount: (json['totalAmount'] ?? 0.0).toDouble(),
      status: json['orderStatus'] ?? '',
      cancellationReason: json['cancellationReason'],
      address: json['address'] ?? '',
      createdAt: DateTime.parse(json['createdAt'] ?? DateTime.now().toIso8601String()),
      updatedAt: DateTime.parse(json['updatedAt'] ?? DateTime.now().toIso8601String()),
      platform: json['platform'] ?? 'app',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      '_id': id,
      'restaurant': restaurantId,
      'restaurantName': restaurantName,
      'customer': customerId,
      'items': items.map((item) => item.toJson()).toList(),
      'totalAmount': totalAmount,
      'orderStatus': status,
      if (cancellationReason != null) 'cancellationReason': cancellationReason,
      'address': address,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'platform': platform,
    };
  }
} 