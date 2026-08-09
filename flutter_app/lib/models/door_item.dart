class PlanItem {
  final String id;
  final String displayName;
  final int annualPriceUsdCents;
  final int maxDoors;
  final int maxHostsPerDoor;
  final int? logRetentionDays;
  final int? logRetentionCount;
  final int monthlyAudioSeconds;
  final int monthlyVideoSeconds;
  final Map<String, bool> features;
  final String subscriptionStatus;
  final DateTime? currentPeriodEnd;
  final DateTime? trialEndsAt;
  final bool isTrial;

  const PlanItem({
    required this.id,
    required this.displayName,
    required this.annualPriceUsdCents,
    required this.maxDoors,
    required this.maxHostsPerDoor,
    required this.logRetentionDays,
    required this.logRetentionCount,
    required this.monthlyAudioSeconds,
    required this.monthlyVideoSeconds,
    required this.features,
    required this.subscriptionStatus,
    required this.currentPeriodEnd,
    required this.trialEndsAt,
    required this.isTrial,
  });

  bool has(String feature) => features[feature] == true;
  bool get isPro => id == 'pro' || id == 'trial';

  factory PlanItem.fromJson(Map<String, dynamic> json) => PlanItem(
        id: json['id'] as String? ?? 'free',
        displayName: json['display_name'] as String? ?? 'Free',
        annualPriceUsdCents:
            (json['annual_price_usd_cents'] as num?)?.toInt() ?? 0,
        maxDoors: (json['max_doors'] as num?)?.toInt() ?? 1,
        maxHostsPerDoor: (json['max_hosts_per_door'] as num?)?.toInt() ?? 1,
        logRetentionDays: (json['log_retention_days'] as num?)?.toInt(),
        logRetentionCount: (json['log_retention_count'] as num?)?.toInt(),
        monthlyAudioSeconds:
            (json['monthly_audio_seconds'] as num?)?.toInt() ?? 0,
        monthlyVideoSeconds:
            (json['monthly_video_seconds'] as num?)?.toInt() ?? 0,
        features:
            Map<String, dynamic>.from(json['features'] as Map? ?? const {})
                .map((key, value) => MapEntry(key, value == true)),
        subscriptionStatus: json['subscription_status'] as String? ?? 'free',
        currentPeriodEnd: json['current_period_end'] == null
            ? null
            : DateTime.tryParse(json['current_period_end'].toString()),
        trialEndsAt: json['trial_ends_at'] == null
            ? null
            : DateTime.tryParse(json['trial_ends_at'].toString()),
        isTrial: json['is_trial'] as bool? ?? json['id'] == 'trial',
      );
}

class DoorSettings {
  final String? welcomeMessage;
  final bool textEnabled;
  final bool audioEnabled;
  final bool videoEnabled;
  final bool requireVisitorName;
  final int ringTimeoutSeconds;

  const DoorSettings({
    this.welcomeMessage,
    this.textEnabled = true,
    this.audioEnabled = false,
    this.videoEnabled = false,
    this.requireVisitorName = false,
    this.ringTimeoutSeconds = 45,
  });

  factory DoorSettings.fromJson(Map<String, dynamic>? json) => DoorSettings(
        welcomeMessage: json?['welcome_message'] as String?,
        textEnabled: json?['text_enabled'] as bool? ?? true,
        audioEnabled: json?['audio_enabled'] as bool? ?? false,
        videoEnabled: json?['video_enabled'] as bool? ?? false,
        requireVisitorName: json?['require_visitor_name'] as bool? ?? false,
        ringTimeoutSeconds:
            (json?['ring_timeout_seconds'] as num?)?.toInt() ?? 45,
      );
}

class DoorItem {
  final String id;
  final String label;
  final String? addressText;
  final bool isActive;
  final String role;
  final DoorSettings settings;
  final PlanItem plan;

  const DoorItem({
    required this.id,
    required this.label,
    this.addressText,
    this.isActive = true,
    this.role = 'owner',
    this.settings = const DoorSettings(),
    required this.plan,
  });

  factory DoorItem.fromJson(Map<String, dynamic> json) {
    final rawSettings = json['settings'] ?? json['door_settings'];
    final settings = rawSettings is List
        ? (rawSettings.isEmpty
            ? null
            : Map<String, dynamic>.from(rawSettings.first as Map))
        : rawSettings is Map
            ? Map<String, dynamic>.from(rawSettings)
            : null;
    return DoorItem(
      id: json['id'] as String,
      label: json['label'] as String,
      addressText: json['address_text'] as String?,
      isActive: json['is_active'] as bool? ?? true,
      role: json['role'] as String? ?? 'owner',
      settings: DoorSettings.fromJson(settings),
      plan: PlanItem.fromJson(Map<String, dynamic>.from(
          json['plan'] as Map? ?? const {'id': 'free'})),
    );
  }

  bool get isOwner => role == 'owner';
  @override
  String toString() => label;
}

class DoorListResult {
  final List<DoorItem> doors;
  final PlanItem accountPlan;
  const DoorListResult(this.doors, this.accountPlan);
}
