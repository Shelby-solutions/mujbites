import 'dart:convert';

enum NotificationType {
  ORDER_PLACED,
  ORDER_ACCEPTED,
  ORDER_DELIVERED,
  ORDER_CANCELLED,
  GENERAL
}

class NotificationModel {
  final String id;
  final String title;
  final String body;
  final NotificationType type;
  final Map<String, dynamic>? payload;
  final DateTime timestamp;
  final String? orderId;
  final String? restaurantId;
  final String? restaurantName;
  final String? status;
  final String? reason;

  NotificationModel({
    required this.id,
    required this.title,
    required this.body,
    required this.type,
    this.payload,
    required this.timestamp,
    this.orderId,
    this.restaurantId,
    this.restaurantName,
    this.status,
    this.reason,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'body': body,
      'type': type.toString().split('.').last,
      'payload': payload,
      'timestamp': timestamp.toIso8601String(),
      if (orderId != null) 'orderId': orderId,
      if (restaurantId != null) 'restaurantId': restaurantId,
      if (restaurantName != null) 'restaurantName': restaurantName,
      if (status != null) 'status': status,
      if (reason != null) 'reason': reason,
    };
  }

  factory NotificationModel.fromJson(Map<String, dynamic> json) {
    return NotificationModel(
      id: json['id'],
      title: json['title'],
      body: json['body'],
      type: _parseNotificationType(json['type']),
      payload: json['payload'],
      timestamp: DateTime.parse(json['timestamp']),
      orderId: json['orderId'],
      restaurantId: json['restaurantId'],
      restaurantName: json['restaurantName'],
      status: json['status'],
      reason: json['reason'],
    );
  }

  factory NotificationModel.fromFCM(Map<String, dynamic> message) {
    final data = message['data'] ?? {};
    final notification = message['notification'];
    
    return NotificationModel(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      title: notification?['title'] ?? data['title'] ?? 'New Notification',
      body: notification?['body'] ?? data['body'] ?? '',
      type: _parseNotificationType(data['type']),
      payload: data,
      timestamp: DateTime.now(),
      orderId: data['orderId'],
      restaurantId: data['restaurantId'],
      restaurantName: data['restaurantName'],
      status: data['status'],
      reason: data['reason'],
    );
  }

  static NotificationType _parseNotificationType(String? type) {
    switch (type?.toUpperCase()) {
      case 'ORDER_PLACED':
        return NotificationType.ORDER_PLACED;
      case 'ORDER_ACCEPTED':
        return NotificationType.ORDER_ACCEPTED;
      case 'ORDER_DELIVERED':
        return NotificationType.ORDER_DELIVERED;
      case 'ORDER_CANCELLED':
        return NotificationType.ORDER_CANCELLED;
      default:
        return NotificationType.GENERAL;
    }
  }

  bool get isOrderNotification => type != NotificationType.GENERAL;
  bool get requiresAction => type == NotificationType.ORDER_PLACED;
  bool get isPositive => type == NotificationType.ORDER_ACCEPTED || type == NotificationType.ORDER_DELIVERED;
  bool get isNegative => type == NotificationType.ORDER_CANCELLED;
} 