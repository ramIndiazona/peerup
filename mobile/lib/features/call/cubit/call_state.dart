import 'package:equatable/equatable.dart';

enum CallPhase { connecting, connected, failed, ended }

class CallState extends Equatable {
  const CallState({
    this.phase = CallPhase.connecting,
    this.elapsedSeconds = 0,
    this.muted = false,
    this.error,
    this.hasRemoteAudio = false,
  });

  final CallPhase phase;
  final int elapsedSeconds;
  final bool muted;
  final String? error;
  final bool hasRemoteAudio;

  CallState copyWith({
    CallPhase? phase,
    int? elapsedSeconds,
    bool? muted,
    String? error,
    bool? hasRemoteAudio,
  }) => CallState(
    phase: phase ?? this.phase,
    elapsedSeconds: elapsedSeconds ?? this.elapsedSeconds,
    muted: muted ?? this.muted,
    error: error ?? this.error,
    hasRemoteAudio: hasRemoteAudio ?? this.hasRemoteAudio,
  );

  @override
  List<Object?> get props => [
    phase,
    elapsedSeconds,
    muted,
    error,
    hasRemoteAudio,
  ];
}
