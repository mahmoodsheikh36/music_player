import 'dart:collection';

class _FunctionQueueEntry {
  Function function;
  Object id;
  _FunctionQueueEntry(this.function, {this.id});
}

class FunctionQueue {
  Queue<_FunctionQueueEntry> _queue = Queue<_FunctionQueueEntry>();
  bool _running = false;

  void add(Function function, {Object id}) {
    _add(_FunctionQueueEntry(function, id: id));
  }

  void _add(_FunctionQueueEntry entry) {
    _queue.add(entry);
    if (!_running)
      _start();
  }

  void _start() {
    _running = true;
    _recurse();
  }

  void _recurse() {
    if (_queue.isEmpty) {
      _running = false;
      return;
    }
    _queue.first.function(() {
      _queue.removeFirst();
      _recurse();
    });
  }

  bool hasEntryWithId(Object id) {
    for (_FunctionQueueEntry entry in _queue) {
      if (entry.id == id) {
        return true;
      }
    }
    return false;
  }

}
