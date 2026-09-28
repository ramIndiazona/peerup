import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/utils/load_state.dart';
import '../ai_repository.dart';

class AIFeedbackCubit extends Cubit<LoadState<dynamic>> {
  AIFeedbackCubit({required String sessionId, required AIRepository repo})
    : _sessionId = sessionId,
      _repo = repo,
      super(const LoadState.loading()) {
    load();
  }

  final String _sessionId;
  final AIRepository _repo;

  Future<void> load() async {
    emit(const LoadState.loading());
    try {
      final feedback = await _repo.getFeedback(_sessionId);
      emit(LoadState.data(feedback));
    } catch (e) {
      emit(LoadState.error(e));
    }
  }
}
