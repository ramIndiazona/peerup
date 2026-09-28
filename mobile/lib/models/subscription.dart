import 'enums.dart';

class SubscriptionStatusResult {
  const SubscriptionStatusResult({
    required this.plan,
    required this.status,
    required this.features,
    this.renewsAt,
    this.canceledAt,
  });

  final SubscriptionPlan plan;
  final SubscriptionStatusEnum status;
  final DateTime? renewsAt;
  final DateTime? canceledAt;
  final Map<String, dynamic> features;

  factory SubscriptionStatusResult.fromJson(Map<String, dynamic> json) =>
      SubscriptionStatusResult(
        plan: SubscriptionPlan.fromApi(json['plan'] as String?),
        status: SubscriptionStatusEnum.fromApi(json['status'] as String?),
        renewsAt: _dt(json['renewsAt']),
        canceledAt: _dt(json['canceledAt']),
        features:
            (json['features'] as Map?)?.cast<String, dynamic>() ?? const {},
      );

  static DateTime? _dt(dynamic v) => v is String ? DateTime.tryParse(v) : null;
}

class UsageResult {
  const UsageResult({
    required this.plan,
    required this.date,
    required this.limits,
  });

  final SubscriptionPlan plan;
  final String date;
  final List<UsageRow> limits;

  factory UsageResult.fromJson(Map<String, dynamic> json) => UsageResult(
    plan: SubscriptionPlan.fromApi(json['plan'] as String?),
    date: (json['date'] as Map?)?['value'] as String? ?? '',
    limits:
        (json['limits'] as List? ?? const [])
            .map((e) => UsageRow.fromJson((e as Map).cast<String, dynamic>()))
            .toList(),
  );
}

class UsageRow {
  const UsageRow({required this.kind, required this.used, required this.limit});

  final String kind;
  final int used;
  final int limit;

  int get remaining => (limit - used).clamp(0, limit);

  factory UsageRow.fromJson(Map<String, dynamic> json) => UsageRow(
    kind: json['kind'] as String? ?? '',
    used: (json['used'] as num?)?.toInt() ?? 0,
    limit: (json['limit'] as num?)?.toInt() ?? 0,
  );
}

class PurchaseResult {
  const PurchaseResult({
    required this.mode,
    this.premiumDays,
    this.expiresAt,
    this.checkoutUrl,
  });

  final String mode;
  final int? premiumDays;
  final DateTime? expiresAt;
  final String? checkoutUrl;

  factory PurchaseResult.fromJson(Map<String, dynamic> json) => PurchaseResult(
    mode: json['mode'] as String? ?? 'checkout',
    premiumDays: (json['premiumDays'] as num?)?.toInt(),
    expiresAt:
        json['expiresAt'] is String
            ? DateTime.tryParse(json['expiresAt'] as String)
            : null,
    checkoutUrl: json['checkoutUrl'] as String?,
  );
}
