class DoorItem {
  final String id;
  final String label;
  final String? addressText;

  DoorItem({required this.id, required this.label, this.addressText});

  factory DoorItem.fromJson(Map<String, dynamic> json) {
    return DoorItem(
      id: json['id'] as String,
      label: json['label'] as String,
      addressText: json['address_text'] as String?,
    );
  }

  @override
  String toString() => label;
}
