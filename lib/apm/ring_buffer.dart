/// A high-performance, fixed-capacity circular buffer (Ring Buffer) that overwrites
/// the oldest elements when full, maintaining constant memory overhead and producing
/// zero garbage collection (GC) pressure.
///
/// ### Architecture & Performance Rationale:
/// In high-frequency telemetry systems (such as 60Hz/120Hz Vsync APM frame timing monitors
/// or high-throughput HTTP traffic inspectors), continuously appending to standard dynamic
/// lists (`List<T>`) triggers repeated array reallocation, internal copying, and frequent
/// GC pauses.
///
/// [RingBuffer] pre-allocates a fixed contiguous memory slice of size [capacity]
/// via `List<T?>.filled(capacity, null, growable: false)`. It manages head and count
/// pointers internally to achieve:
/// 1. **O(1) Insertion**: Constant time overwriting of stale telemetry data.
/// 2. **O(1) Random Access**: Direct logical-to-physical index mapping via modular arithmetic.
/// 3. **Zero Heap Resizing**: The backing buffer never reallocates, eliminating heap fragmentation.
class RingBuffer<T> {
  /// Maximum number of items this circular buffer can hold simultaneously.
  final int capacity;

  /// Backing array with fixed pre-allocated capacity.
  final List<T?> _buffer;

  /// Physical pointer to the next insertion slot in [_buffer].
  int _head = 0;

  /// Current number of valid items stored (0 <= _count <= capacity).
  int _count = 0;

  /// Creates a [RingBuffer] with a fixed [capacity].
  ///
  /// Allocates a non-growable contiguous array immediately to prevent future heap reallocations.
  RingBuffer(this.capacity)
      : _buffer = List<T?>.filled(capacity, null, growable: false);

  /// Adds a new [item] to the buffer in O(1) time.
  ///
  /// If the buffer has reached [capacity], the oldest element at [_head] is overwritten
  /// and [_head] advances circularly: `(_head + 1) % capacity`.
  void add(T item) {
    _buffer[_head] = item;
    _head = (_head + 1) % capacity;
    if (_count < capacity) {
      _count++;
    }
  }

  /// Clears all elements in the buffer and resets head and count pointers.
  ///
  /// Fills the backing array with `null` to facilitate immediate GC of referenced items.
  void clear() {
    _buffer.fillRange(0, capacity, null);
    _head = 0;
    _count = 0;
  }

  /// Returns the current number of valid elements in the buffer.
  int get length => _count;

  /// Returns true if the buffer contains no elements.
  bool get isEmpty => _count == 0;

  /// Returns true if the buffer contains at least one element.
  bool get isNotEmpty => _count > 0;

  /// Returns true if the buffer has reached maximum capacity.
  bool get isFull => _count == capacity;

  /// Accesses elements in logical chronological order in O(1) time:
  /// - `index = 0` yields the oldest surviving element.
  /// - `index = length - 1` yields the newest element.
  ///
  /// ### Physical Modulo Mapping:
  /// - When not yet full (`_count < capacity`), elements are stored from physical slot `0` to `_count - 1`.
  /// - When full (`_count == capacity`), the oldest element currently resides at [_head].
  ///   The physical index is calculated as: `(physicalIndex = (_head + index) % capacity)`.
  ///
  /// Throws [RangeError] if [index] is negative or `>= length`.
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

  /// Exports an immutable snapshot list of the current buffer contents in chronological order.
  ///
  /// ### Performance Notice:
  /// This operation performs an array allocation and copy (O(N) time and memory).
  /// For high-frequency loops (such as Vsync render frames), prefer iterating directly via
  /// `for (int i = 0; i < buffer.length; i++) buffer[i]` to avoid GC overhead.
  List<T> toList() {
    if (_count == 0) return <T>[];
    final list = List<T>.generate(_count, (i) => this[i], growable: false);
    return list;
  }
}
