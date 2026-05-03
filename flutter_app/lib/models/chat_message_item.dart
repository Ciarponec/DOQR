class ChatMessageItem {
  final String id;
  final String ringId;
  final String senderType;
  final String text;
  final DateTime createdAt;

  ChatMessageItem({
    required this.id,
    required this.ringId,
    required this.senderType,
    required this.text,
    required this.createdAt,
  });

  factory ChatMessageItem.fromJson(Map<String, dynamic> json) {
    return ChatMessageItem(
      id: json['id'] as String,
      ringId: json['ring_id'] as String,
      senderType: json['sender_type'] as String,
      text: json['message_text'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }
}
