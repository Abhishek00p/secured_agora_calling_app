/// Runs async work over [items] with at most [concurrency] tasks in flight.
class AsyncTaskPool {
  const AsyncTaskPool({this.concurrency = 5});

  final int concurrency;

  Future<List<R>> map<T, R>(Iterable<T> items, Future<R> Function(T item) task) async {
    final list = items.toList();
    if (list.isEmpty) return <R>[];

    final results = List<R?>.filled(list.length, null);
    var nextIndex = 0;

    Future<void> worker() async {
      while (true) {
        final index = nextIndex;
        nextIndex++;
        if (index >= list.length) return;
        results[index] = await task(list[index]);
      }
    }

    final workerCount = concurrency.clamp(1, list.length);
    await Future.wait(List.generate(workerCount, (_) => worker()));
    return results.cast<R>();
  }
}
