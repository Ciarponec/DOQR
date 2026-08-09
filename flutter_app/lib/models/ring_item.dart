class RingItem {
  final String id;
  final String doorId;
  final String status;
  final String requestedMode;
  final String? acceptedMode;
  final String visitorKind;
  final String? visitorAlias;
  final String? courierCode;
  final String? courierNoteId;
  final Map<String, dynamic> clientMetadata;
  final DateTime createdAt;
  final DateTime? answeredAt;
  final DateTime? closedAt;

  const RingItem({
    required this.id,
    required this.doorId,
    required this.status,
    required this.requestedMode,
    required this.visitorKind,
    required this.createdAt,
    this.acceptedMode,
    this.visitorAlias,
    this.courierCode,
    this.courierNoteId,
    this.clientMetadata = const {},
    this.answeredAt,
    this.closedAt,
  });

  bool get isActive => status == 'pending' || status == 'accepted';
  bool get usesMedia => requestedMode == 'audio' || requestedMode == 'video';

  factory RingItem.fromJson(Map<String, dynamic> json) => RingItem(
        id: json['id'] as String,
        doorId: json['door_id'] as String,
        status: json['status'] as String? ?? 'pending',
        requestedMode: json['requested_mode'] as String? ?? 'text',
        acceptedMode: json['accepted_mode'] as String?,
        visitorKind: json['visitor_kind'] as String? ?? 'guest',
        visitorAlias: json['visitor_alias'] as String?,
        courierCode: json['courier_code'] as String?,
        courierNoteId: json['courier_note_id'] as String?,
        clientMetadata: Map<String, dynamic>.from(
            json['client_metadata'] as Map? ?? const {}),
        createdAt: DateTime.parse(json['created_at'] as String),
        answeredAt: json['answered_at'] == null
            ? null
            : DateTime.parse(json['answered_at'] as String),
        closedAt: json['closed_at'] == null
            ? null
            : DateTime.parse(json['closed_at'] as String),
      );
}
