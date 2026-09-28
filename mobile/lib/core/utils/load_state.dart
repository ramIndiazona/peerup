enum LoadStatus { idle, loading, loaded, error }

class LoadState<T> {
  const LoadState.idle() : status = LoadStatus.idle, value = null, error = null;

  const LoadState.loading()
    : status = LoadStatus.loading,
      value = null,
      error = null;

  const LoadState.data(T this.value) : status = LoadStatus.loaded, error = null;

  const LoadState.error(Object this.error)
    : status = LoadStatus.error,
      value = null;

  final LoadStatus status;
  final T? value;
  final Object? error;

  bool get isIdle => status == LoadStatus.idle;
  bool get isLoading => status == LoadStatus.loading;
  bool get isLoaded => status == LoadStatus.loaded;
  bool get hasError => status == LoadStatus.error;

  T? get valueOrNull => value;

  T requireData() => value as T;
}
