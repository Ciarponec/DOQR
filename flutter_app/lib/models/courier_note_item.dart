class CourierNoteItem {
  final String id;
  final String courierCode;
  final String courierLabel;
  final String title;
  final String message;
  final String? deliveryCode;
  final bool isActive;

  const CourierNoteItem({
    required this.id,
    required this.courierCode,
    required this.courierLabel,
    required this.title,
    required this.message,
    required this.isActive,
    this.deliveryCode,
  });

  factory CourierNoteItem.fromJson(Map<String, dynamic> json) =>
      CourierNoteItem(
        id: json['id'] as String,
        courierCode: json['courier_code'] as String,
        courierLabel: json['courier_label'] as String,
        title: json['title'] as String,
        message: json['message_text'] as String,
        deliveryCode: json['delivery_code'] as String?,
        isActive: json['is_active'] as bool? ?? true,
      );
}
