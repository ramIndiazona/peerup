import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/matchmaking/matchmaking_service.dart';
import '../../../core/network/api_exception.dart';
import '../../../models/matchmaking.dart';
import 'matchmaking_state.dart';

/// Thin UI projection of [MatchmakingService]. REST calls, socket events and
/// live-presence coordination live in the service; this cubit tracks the
/// MatchPhase and surfaces match data for navigation.
class MatchmakingCubit extends Cubit<MatchState> {
  MatchmakingCubit({required MatchmakingService service})
    : _service = service,
      super(const MatchState()) {
    _sub = _service.events.listen(_onEvent);
  }

  final MatchmakingService _service;
  StreamSubscription<MatchmakingEvent>? _sub;
  bool _matched = false;
  MatchFilters? _lastFilters;

  /// Full search flow (UI entry point).
  Future<void> start(MatchFilters filters) async {
    if (_matched || state.isSearching || state.phase == MatchPhase.matched) {
      debugPrint('[Match] start ignored (already active)');
      return;
    }
    _lastFilters = filters;
    emit(const MatchState(phase: MatchPhase.starting));
    try {
      final ok = await _service.start(filters);
      if (!ok) {
        debugPrint('[Match] not live -> abort before matchmaking start');
        emit(
          state.copyWith(
            phase: MatchPhase.idle,
            clearMatch: true,
            error:
                'You must be live before searching. '
                'Check your connection and try again.',
          ),
        );
        return;
      }
      debugPrint('[Match] waiting');
      emit(state.copyWith(phase: MatchPhase.searching));
    } on ApiException catch (e) {
      debugPrint('[Match] error code=${e.code} message=${e.message}');
      emit(
        state.copyWith(
          phase: MatchPhase.idle,
          clearMatch: true,
          error: e.message,
        ),
      );
    } on Exception catch (e) {
      debugPrint('[Match] unexpected error $e');
      emit(
        state.copyWith(phase: MatchPhase.idle, clearMatch: true, error: '$e'),
      );
    }
  }

  /// Restore a search after app restart / reconnect / deep link.
  Future<void> recover(MatchFilters filters) async {
    if (_matched || state.isSearching || state.phase == MatchPhase.matched) {
      return;
    }
    _lastFilters = filters;
    final result = await _service.recover(filters);
    if (result.outcome == RecoverOutcome.searching) {
      debugPrint('[Match] recovered: already searching');
      emit(state.copyWith(phase: MatchPhase.searching));
      return;
    }
    if (result.outcome == RecoverOutcome.matched && result.match != null) {
      debugPrint(
        '[Match] recovered: matched call=${result.match!.callId} '
        'peer=${result.match!.peer.id}',
      );
      _matched = true;
      emit(state.copyWith(phase: MatchPhase.matched, match: result.match));
      return;
    }
    debugPrint('[Match] no active search on backend; starting fresh');
    await start(filters);
  }

  Future<void> cancel() async {
    // Once matched we must NOT tear the match down — the caller screen
    // depends on the match data to start the call.
    if (state.phase == MatchPhase.matched) return;
    await _service.cancel();
    _matched = false;
    emit(
      state.copyWith(
        phase: MatchPhase.idle,
        clearMatch: true,
        clearError: true,
      ),
    );
  }

  void reset() {
    _matched = false;
    _lastFilters = null;
    emit(const MatchState());
  }

  void _onEvent(MatchmakingEvent event) {
    switch (event.type) {
      case MatchmakingEventType.connected:
        if (state.phase == MatchPhase.searching && _lastFilters != null) {
          unawaited(_service.restoreAfterReconnect(_lastFilters!));
        }
      case MatchmakingEventType.matched:
        // Guard: one MATCH_FOUND may arrive; navigation must happen only once.
        if (_matched) return;
        _matched = true;
        emit(
          state.copyWith(
            phase: MatchPhase.matched,
            match: event.match,
            clearError: true,
          ),
        );
      case MatchmakingEventType.cancelled:
        if (state.isSearching) {
          _matched = false;
          emit(
            state.copyWith(
              phase: MatchPhase.idle,
              clearMatch: true,
              clearError: true,
            ),
          );
        }
      case MatchmakingEventType.timeout:
        _matched = false;
        emit(
          state.copyWith(
            phase: MatchPhase.idle,
            clearMatch: true,
            error: 'No partner found this time. Give it another try!',
          ),
        );
    }
  }

  @override
  Future<void> close() async {
    await _sub?.cancel();
    await super.close();
  }
}
