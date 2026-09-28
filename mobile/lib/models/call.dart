import 'enums.dart';
import 'profile.dart';

class CallDetails {
  const CallDetails({required this.call, this.peerId});

  final CallSessionSummary call;
  final String? peerId;

  factory CallDetails.fromJson(Map<String, dynamic> json) => CallDetails(
    call: CallSessionSummary.fromJson(
      ((json['call'] as Map?) ?? const {}).cast<String, dynamic>(),
    ),
    peerId: json['peerId'] as String?,
  );
}

class CallSessionSummary {
  const CallSessionSummary({
    this.id,
    this.status = CallStatus.matched,
    this.startedAt,
    this.connectedAt,
    this.endedAt,
    this.duration,
    this.endReason,
  });

  final String? id;
  final CallStatus status;
  final DateTime? startedAt;
  final DateTime? connectedAt;
  final DateTime? endedAt;
  final int? duration;
  final CallEndReason? endReason;

  factory CallSessionSummary.fromJson(Map<String, dynamic> json) =>
      CallSessionSummary(
        id: json['id'] as String?,
        status: CallStatus.fromApi(json['status'] as String?),
        startedAt: _dt(json['startedAt']),
        connectedAt: _dt(json['connectedAt']),
        endedAt: _dt(json['endedAt']),
        duration: (json['duration'] as num?)?.toInt(),
        endReason: CallEndReason.fromApi(json['endReason'] as String?),
      );

  static DateTime? _dt(dynamic v) => v is String ? DateTime.tryParse(v) : null;
}

class MatchFoundData {
  const MatchFoundData({
    required this.callId,
    required this.role,
    required this.peer,
  });

  final String callId;
  final String role;
  final PublicProfile peer;

  factory MatchFoundData.fromJson(Map<String, dynamic> json) => MatchFoundData(
    callId: json['callId'] as String? ?? '',
    role: json['role'] as String? ?? 'caller',
    peer: PublicProfile.fromJson(
      ((json['peer'] as Map?) ?? const {}).cast<String, dynamic>(),
    ),
  );
}

class CallEndedData {
  const CallEndedData({
    required this.callId,
    required this.reason,
    this.duration,
    this.endedBy,
  });

  final String callId;
  final CallEndReason reason;
  final int? duration;
  final String? endedBy;

  factory CallEndedData.fromJson(Map<String, dynamic> json) => CallEndedData(
    callId: json['callId'] as String? ?? '',
    reason: CallEndReason.fromApi(json['reason'] as String?),
    duration: (json['duration'] as num?)?.toInt(),
    endedBy: json['endedBy'] as String?,
  );
}

class SignalingData {
  const SignalingData({
    required this.callId,
    required this.from,
    required this.data,
  });

  final String callId;
  final String from;
  final dynamic data;

  factory SignalingData.fromJson(Map<String, dynamic> json) => SignalingData(
    callId: json['callId'] as String? ?? '',
    from: json['from'] as String? ?? '',
    data: json['data'],
  );
}

class BlockedUser {
  const BlockedUser({required this.id, this.name, this.avatar});

  final String id;
  final String? name;
  final String? avatar;

  factory BlockedUser.fromJson(Map<String, dynamic> json) {
    final blocked = (json['blocked'] as Map?) ?? const {};
    final profile = (blocked['profile'] as Map?) ?? const {};
    return BlockedUser(
      id: blocked['id'] as String? ?? '',
      name: profile['name'] as String?,
      avatar: profile['avatar'] as String?,
    );
  }
}
