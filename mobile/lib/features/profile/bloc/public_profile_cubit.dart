import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/utils/load_state.dart';
import '../../../models/profile.dart';
import '../profile_repository.dart';

class PublicProfileCubit extends Cubit<LoadState<PublicProfile>> {
  PublicProfileCubit({
    required String userId,
    required ProfileRepository profileRepository,
  }) : _userId = userId,
       _repo = profileRepository,
       super(const LoadState.loading()) {
    load();
  }

  final String _userId;
  final ProfileRepository _repo;

  Future<void> load() async {
    emit(const LoadState.loading());
    try {
      final profile = await _repo.getPublicProfile(_userId);
      emit(LoadState.data(profile));
    } catch (e) {
      emit(LoadState.error(e));
    }
  }
}
