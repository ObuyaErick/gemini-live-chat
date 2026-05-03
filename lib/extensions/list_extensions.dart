extension IterableExtensions<T> on Iterable<T> {
  Iterable<R> mapIndexed<R>(R Function(T element, int index) f) {
    var index = 0;
    return map((e) => f(e, index++));
  }
}
