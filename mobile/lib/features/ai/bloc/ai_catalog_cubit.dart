import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/utils/load_state.dart';
import '../../../models/ai.dart';
import '../ai_repository.dart';

class AICatalogState {
  const AICatalogState({
    this.characters = const LoadState.idle(),
    this.scenarios = const LoadState.idle(),
  });

  final LoadState<List<AICharacter>> characters;
  final LoadState<List<String>> scenarios;

  AICatalogState copyWith({
    LoadState<List<AICharacter>>? characters,
    LoadState<List<String>>? scenarios,
  }) => AICatalogState(
    characters: characters ?? this.characters,
    scenarios: scenarios ?? this.scenarios,
  );
}

class AICatalogCubit extends Cubit<AICatalogState> {
  AICatalogCubit({required AIRepository repo})
    : _repo = repo,
      super(const AICatalogState());

  final AIRepository _repo;

  Future<void> load() async {
    emit(
      AICatalogState(
        characters: const LoadState.loading(),
        scenarios: const LoadState.loading(),
      ),
    );

    List<AICharacter> characters = const [];
    List<String> scenarios = const [];

    Object? charactersError;
    Object? scenariosError;

    try {
      characters = await _repo.listCharacters();
    } catch (e) {
      charactersError = e;
    }

    try {
      scenarios = await _repo.listScenarios();
    } catch (e) {
      scenariosError = e;
    }

    emit(
      AICatalogState(
        characters:
            charactersError != null
                ? LoadState.error(charactersError)
                : LoadState.data(characters),
        scenarios:
            scenariosError != null
                ? LoadState.error(scenariosError)
                : LoadState.data(scenarios),
      ),
    );
  }
}
