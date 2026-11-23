import 'package:modu_reader/service/todo/todo_note.dart';

/// Publishes uncleared notes into the phone notification shade.
abstract class TodoShade {
  Future<void> sync(List<TodoNote> notes);
}

class NoopTodoShade implements TodoShade {
  const NoopTodoShade();

  @override
  Future<void> sync(List<TodoNote> notes) async {}
}
