import 'dart:convert';
import 'dart:math' show max;

class NotificationModel {
  final String type;
  final String orderId;
  final String? restaurantId;
  final String restaurantName;
  final String amount;
  final String status;
  final String platform;
  final String timestamp;
  final Map<String, dynamic>? additionalData;

  NotificationModel({
    required this.type,
    required this.orderId,
    this.restaurantId,
    required this.restaurantName,
    required this.amount,
    required this.status,
    required this.platform,
    required this.timestamp,
    this.additionalData,
  });

  factory NotificationModel.fromJson(Map<String, dynamic> json) {
    return NotificationModel(
      type: json['type'] ?? '',
      orderId: json['orderId'] ?? '',
      restaurantId: json['restaurantId'],
      restaurantName: json['restaurantName'] ?? '',
      amount: json['amount'] ?? '0',
      status: json['status'] ?? '',
      platform: json['platform'] ?? 'app',
      timestamp: json['timestamp'] ?? DateTime.now().toIso8601String(),
      additionalData: json['additionalData'],
    );
  }

  factory NotificationModel.fromRemoteMessage(Map<String, dynamic> message) {
    final data = message['data'] ?? {};
    return NotificationModel(
      type: data['type'] ?? '',
      orderId: data['orderId'] ?? '',
      restaurantId: data['restaurantId'],
      restaurantName: data['restaurantName'] ?? '',
      amount: data['amount'] ?? '0',
      status: data['status'] ?? '',
      platform: data['platform'] ?? 'app',
      timestamp: data['timestamp'] ?? DateTime.now().toIso8601String(),
      additionalData: Map<String, dynamic>.from(data)
        ..removeWhere((key, _) => [
          'type',
          'orderId',
          'restaurantId',
          'restaurantName',
          'amount',
          'status',
          'platform',
          'timestamp'
        ].contains(key)),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'type': type,
      'orderId': orderId,
      if (restaurantId != null) 'restaurantId': restaurantId,
      'restaurantName': restaurantName,
      'amount': amount,
      'status': status,
      'platform': platform,
      'timestamp': timestamp,
      if (additionalData != null) ...additionalData!,
    };
  }

  String get notificationTitle {
    switch (type) {
      case 'ORDER_PLACED':
        return 'Order Placed Successfully';
      case 'ORDER_CONFIRMED':
        return 'Order Confirmed';
      case 'ORDER_READY':
        return 'Order Ready for Pickup';
      case 'ORDER_DELIVERED':
        return 'Order Delivered';
      case 'ORDER_CANCELLED':
        return 'Order Cancelled';
      default:
        return 'Order Update';
    }
  }

  String get notificationBody {
    switch (type) {
      case 'ORDER_PLACED':
        return 'Your order at $restaurantName has been placed';
      case 'ORDER_CONFIRMED':
        return '$restaurantName has confirmed your order';
      case 'ORDER_READY':
        return 'Your order at $restaurantName is ready for pickup';
      case 'ORDER_DELIVERED':
        return 'Your order from $restaurantName has been delivered';
      case 'ORDER_CANCELLED':
        return 'Your order at $restaurantName has been cancelled';
      default:
        return 'Update for your order at $restaurantName';
    }
  }

  String get restaurantNotificationBody {
    final orderNumber = orderId.substring(max(0, orderId.length - 6));
    switch (type) {
      case 'ORDER_PLACED':
        return 'New order #$orderNumber - ₹$amount';
      case 'ORDER_CONFIRMED':
        return 'Order #$orderNumber has been confirmed';
      case 'ORDER_READY':
        return 'Order #$orderNumber is ready for pickup';
      case 'ORDER_DELIVERED':
        return 'Order #$orderNumber has been delivered';
      case 'ORDER_CANCELLED':
        return 'Order #$orderNumber has been cancelled';
      default:
        return 'Update for order #$orderNumber';
    }
  }

  bool get isHighPriority => 
    type == 'ORDER_PLACED' || type == 'ORDER_CANCELLED';

  List<NotificationAction> getActions(bool isRestaurant) {
    if (isRestaurant) {
      switch (type) {
        case 'ORDER_PLACED':
          return [
            NotificationAction('accept', 'Accept Order'),
            NotificationAction('view', 'View Details'),
          ];
        case 'ORDER_CONFIRMED':
        case 'ORDER_READY':
          return [
            NotificationAction('view', 'View Order'),
            NotificationAction('contact', 'Contact Customer'),
          ];
        default:
          return [NotificationAction('view', 'View Details')];
      }
    } else {
      switch (type) {
        case 'ORDER_PLACED':
          return [
            NotificationAction('view', 'View Order'),
            NotificationAction('track', 'Track Order'),
          ];
        case 'ORDER_CONFIRMED':
          return [
            NotificationAction('track', 'Track Order'),
            NotificationAction('contact', 'Contact Restaurant'),
          ];
        case 'ORDER_READY':
          return [
            NotificationAction('track', 'Track Order'),
            NotificationAction('directions', 'Get Directions'),
          ];
        case 'ORDER_DELIVERED':
          return [
            NotificationAction('review', 'Rate Order'),
            NotificationAction('reorder', 'Order Again'),
          ];
        default:
          return [NotificationAction('view', 'View Details')];
      }
    }
  }
}

class NotificationAction {
  final String action;
  final String title;

  NotificationAction(this.action, this.title);

  Map<String, dynamic> toJson() => {
    'action': action,
    'title': title,
  };
} 