class Order {
  final String id;
  final String orderNumber;
  final String status;
  final double totalAmount;
  final String studentName;
  final String studentPhone;
  final String? campus;
  final String? hostelBlock;
  final String? roomNumber;
  final double discountAmount;
  final String? couponCode;
  final List<dynamic> items;

  Order({
    required this.id, required this.orderNumber, required this.status, required this.totalAmount,
    required this.studentName, required this.studentPhone, this.campus, this.hostelBlock, this.roomNumber, required this.items,
    this.discountAmount = 0.0, this.couponCode,
  });

  factory Order.fromJson(Map<String, dynamic> json) {
    return Order(
      id: json['id'].toString(),
      orderNumber: json['order_number'] ?? '',
      status: json['status'] ?? 'unknown',
      totalAmount: double.parse(json['total_amount']?.toString() ?? '0'),
      studentName: json['student']?['name'] ?? 'Student',
      studentPhone: json['student']?['phone'] ?? '',
      campus: json['campus'],
      hostelBlock: json['hostel_block'],
      roomNumber: json['room_number'],
      discountAmount: double.tryParse(json['discount_amount']?.toString() ?? '0') ?? 0.0,
      couponCode: json['coupon_code']?.toString() ?? json['coupon']?.toString(),
      items: json['items'] as List? ?? [],
    );
  }
}