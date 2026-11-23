import 'package:modu_reader/service/todo/todo_note.dart';
import 'package:modu_reader/service/todo/todo_shade.dart';
import 'package:modu_reader/service/todo/todo_shade_factory.dart';
import 'package:modu_reader/service/todo/todo_store.dart';
import 'package:flutter/foundation.dart';

class TodoNotes extends ChangeNotifier {
  TodoNotes({TodoNoteStore? store, TodoShade? shade})
      : _store = store ?? SharedPreferencesTodoNoteStore(),
        _shade = shade ?? createPlatformTodoShade();

  static final TodoNotes instance = TodoNotes();

  final TodoNoteStore _store;
  final TodoShade _shade;
  List<TodoNote> _notes = [];
  Future<void>? _loading;

  List<TodoNote> get notes => List.unmodifiable(_notes);

  List<TodoNote> get active {
    final items = activeTodoNotes(_notes);
    items.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return items;
  }

  List<TodoNote> get cleared {
    final items = _notes.where((note) => note.cleared).toList();
    items.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return items;
  }

  Future<void> ensureLoaded() => _loading ??= _load();

  Future<void> _load() async {
    _notes = await _store.load();
    notifyListeners();
    await _shade.sync(_notes);
  }

  Future<TodoNote?> add({
    required String title,
    required String markdown,
  }) async {
    await ensureLoaded();
    final trimmed = title.trim();
    if (trimmed.isEmpty) return null;
    final note = TodoNote(
      id: '${DateTime.now().microsecondsSinceEpoch}',
      notificationId: nextNotificationId(_notes),
      title: trimmed,
      markdown: markdown.trim(),
      createdAt: DateTime.now(),
      cleared: false,
    );
    _notes = [note, ..._notes];
    await _persist();
    return note;
  }

  Future<void> update(
    String id, {
    required String title,
    required String markdown,
  }) async {
    await ensureLoaded();
    final trimmed = title.trim();
    if (trimmed.isEmpty) return;
    _notes = [
      for (final note in _notes)
        if (note.id == id && !note.cleared)
          note.copyWith(title: trimmed, markdown: markdown.trim())
        else
          note,
    ];
    await _persist();
  }

  /// Cleared notes stay in the list and leave the notification shade.
  Future<void> clear(String id) async {
    await ensureLoaded();
    _notes = [
      for (final note in _notes)
        if (note.id == id) note.copyWith(cleared: true) else note,
    ];
    await _persist();
  }

  Future<void> delete(String id) async {
    await ensureLoaded();
    _notes = _notes.where((note) => note.id != id).toList(growable: false);
    await _persist();
  }

  Future<void> _persist() async {
    await _store.save(_notes);
    notifyListeners();
    await _shade.sync(_notes);
  }
}
