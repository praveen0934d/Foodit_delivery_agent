class DeliveryProfile {
  final String id;
  final String name;
  final String phone;
  final int activeOrdersCount;
  final int totalDelivered;
  final int totalNotPickedUp; 

  DeliveryProfile({
    required this.id, required this.name, required this.phone,
    required this.activeOrdersCount, required this.totalDelivered, required this.totalNotPickedUp,
  });

  factory DeliveryProfile.fromJson(Map<String, dynamic> json) {
    final agent = json['agent'] ?? {};
    return DeliveryProfile(
      id: agent['id']?.toString() ?? '',
      name: agent['name'] ?? 'Delivery Agent',
      phone: agent['phone'] ?? '',
      activeOrdersCount: json['active_orders_count'] ?? 0,
      totalDelivered: json['total_delivered'] ?? 0,
      totalNotPickedUp: json['total_not_picked_up'] ?? 0, 
    );
  }
}