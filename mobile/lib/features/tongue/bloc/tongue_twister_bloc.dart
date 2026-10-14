
import 'package:flutter_bloc/flutter_bloc.dart';

import 'tongue_twister_event.dart';
import 'tongue_twister_state.dart';
import '../data/tongue_twister_repository.dart';

class TongueTwisterBloc extends Bloc<TongueTwisterEvent, TongueTwisterState> {
  final TongueTwisterRepository repository;

  TongueTwisterBloc(this.repository)
      : super(TongueTwisterInitial()) 
      {
    on<FetchTongueTwisters>((event, emit) async 
    {
      emit(TongueTwisterLoading());

      try {
        final twisters =
            await repository.fetchTongueTwisters();

        emit(TongueTwisterLoaded(twisters));
      } catch (e) {
        emit(
          TongueTwisterError(
            'Failed to load tongue twisters: $e',
          ),
        );
      }
    });
  }
}
