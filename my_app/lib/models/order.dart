import 'package:my_app/models/cart.dart';

class OrderItem {
  final String menuItemId;
  final String itemName;
  final int quantity;
  final String size;

  OrderItem({
    required this.menuItemId,
    required this.itemName,
    required this.quantity,
    required this.size,
  });

  Map<String, dynamic> toJson() => {
    'menuItem': menuItemId,
    'itemName': itemName,
    'quantity': quantity,
    'size': size,
  };

  factory OrderItem.fromJson(Map<String, dynamic> json) => OrderItem(
    menuItemId: json['menuItem'],
    itemName: json['itemName'],
    quantity: json['quantity'],
    size: json['size'],
  );

  factory OrderItem.fromCartItem(CartItem item) => OrderItem(
    menuItemId: item.id,
    itemName: item.name,
    quantity: item.quantity,
    size: item.size,
  );
}

class Order {
  final String? id;
  final String restaurantId;
  final String restaurantName;
  final String customerId;
  final List<OrderItem> items;
  final double totalAmount;
  final String address;
  final String orderStatus;
  final String? cancellationReason;
  final DateTime createdAt;
  final DateTime updatedAt;

  Order({
    this.id,
    required this.restaurantId,
    required this.restaurantName,
    required this.customerId,
    required this.items,
    required this.totalAmount,
    required this.address,
    this.orderStatus = 'Placed',
    this.cancellationReason,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) : 
    this.createdAt = createdAt ?? DateTime.now(),
    this.updatedAt = updatedAt ?? DateTime.now();

  Map<String, dynamic> toJson() => {
    if (id != null) '_id': id,
    'restaurant': restaurantId,
    'restaurantName': restaurantName,
    'customer': customerId,
    'items': items.map((item) => item.toJson()).toList(),
    'totalAmount': totalAmount,
    'address': address,
    'orderStatus': orderStatus,
    if (cancellationReason != null) 'cancellationReason': cancellationReason,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
  };

  factory Order.fromJson(Map<String, dynamic> json) => Order(
    id: json['_id'],
    restaurantId: json['restaurant'],
    restaurantName: json['restaurantName'],
    customerId: json['customer'],
    items: (json['items'] as List)
        .map((item) => OrderItem.fromJson(item))
        .toList(),
    totalAmount: json['totalAmount'].toDouble(),
    address: json['address'],
    orderStatus: json['orderStatus'],
    cancellationReason: json['cancellationReason'],
    createdAt: DateTime.parse(json['createdAt']),
    updatedAt: DateTime.parse(json['updatedAt']),
  );
} 