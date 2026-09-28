import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/utils/load_state.dart';
import '../../../models/profile.dart';
import '../profile_repository.dart';

class ProfileCubit extends Cubit<LoadState<UserProfile>> {
  ProfileCubit({required ProfileRepository profileRepository})
    : _repo = profileRepository,
      super(const LoadState.idle());

  final ProfileRepository _repo;

  Future<void> load() async {
    emit(const LoadState.loading());
    try {
      final user = await _repo.getMe();
      emit(LoadState.data(user));
    } catch (e) {
      emit(LoadState.error(e));
    }
  }

  Future<UserProfile> save(Map<String, dynamic> patch) async {
    final user = await _repo.updateProfile(patch);
    emit(LoadState.data(user));
    return user;
  }
}
