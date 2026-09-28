import 'package:equatable/equatable.dart';

import '../../../models/call.dart';

enum MatchPhase { idle, starting, searching, matched }

class MatchState extends Equatable {
  const MatchState({this.phase = MatchPhase.idle, this.match, this.error});

  final MatchPhase phase;
  final MatchFoundData? match;
  final String? error;

  bool get isSearching =>
      phase == MatchPhase.starting || phase == MatchPhase.searching;

  MatchState copyWith({
    MatchPhase? phase,
    MatchFoundData? match,
    bool clearMatch = false,
    String? error,
    bool clearError = false,
  }) => MatchState(
    phase: phase ?? this.phase,
    match: clearMatch ? null : (match ?? this.match),
    error: clearError ? null : (error ?? this.error),
  );

  @override
  List<Object?> get props => [phase, match, error];
}
