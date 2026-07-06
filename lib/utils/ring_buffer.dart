/// A high-performance, fixed-capacity circular buffer that overwrites the oldest
/// elements when full, producing zero garbage collection (GC) pressure.
///
/// Designed to avoid frequent array copying (toList) during high-frequency
/// frame rendering statistics.
class RingBuffer<T> {
  final int capacity;
  final List<T?> _buffer;
  int _head = 0;
  int _count = 0;

  RingBuffer(this.capacity)
      : _buffer = List<T?>.filled(capacity, null, growable: false);

  /// Adds a new item to the buffer, overwriting the oldest one if the buffer is full.
  void add(T item) {
    _buffer[_head] = item;
    _head = (_head + 1) % capacity;
    if (_count < capacity) {
      _count++;
    }
  }

  /// Clears all elements in the buffer.
  void clear() {
    _buffer.fillRange(0, capacity, null);
    _head = 0;
    _count = 0;
  }

  /// Returns the current number of elements in the buffer.
  int get length => _count;

  /// Returns true if the buffer is empty.
  bool get isEmpty => _count == 0;

  /// Returns true if the buffer is not empty.
  bool get isNotEmpty => _count > 0;

  /// Returns true if the buffer is full.
  bool get isFull => _count == capacity;

  /// Accesses elements in chronological order (0 is the oldest, [length - 1] is the newest).
  ///
  /// Out-of-bounds access throws a [RangeError].
  T operator [](int index) {
    if (index < 0 || index >= _count) {
      throw RangeError.range(index, 0, _count - 1, 'index');
    }
    // Calculate the physical index in the underlying ring array
    final int physicalIndex;
    if (_count < capacity) {
      physicalIndex = index;
    } else {
      physicalIndex = (_head + index) % capacity;
    }
    return _buffer[physicalIndex] as T;
  }

  /// Computes a list representation of the buffer.
  /// Use this only when array copying is acceptable (e.g., UI initialization or logging).
  List<T> toList() {
    if (_count == 0) return <T>[];
    final list = List<T>.generate(_count, (i) => this[i], growable: false);
    return list;
  }
}
