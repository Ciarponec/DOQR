class RingItem {
  final String id;
  final String doorId;
  final String status;
  final DateTime createdAt;

  RingItem({required this.id, required this.doorId, required this.status, required this.createdAt});

  factory RingItem.fromJson(Map<String, dynamic> json) {
    return RingItem(
      id: json['id'] as String,
      doorId: json['door_id'] as String,
      status: json['status'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }
}
