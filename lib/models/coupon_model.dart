
class CouponModel {
  final String id;
  final String code;
  final String discountType; // 'percentage' or 'flat'
  final double value;
  final bool isActive;

  CouponModel({
    required this.id,
    required this.code,
    required this.discountType,
    required this.value,
    this.isActive = true,
  });

  factory CouponModel.fromJson(Map<String, dynamic> json) {
    return CouponModel(
      id: json['id'],
      code: json['code'],
      discountType: json['discount_type'],
      value: (json['value'] as num).toDouble(),
      isActive: json['is_active'] ?? true,
    );
  }

  double calculateDiscount(double subtotal) {
    if (discountType == 'percentage') {
      return (subtotal * value) / 100;
    } else {
      return value;
    }
  }
}
