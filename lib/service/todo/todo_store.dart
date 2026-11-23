import 'dart:convert';

import 'package:modu_reader/service/todo/todo_note.dart';
import 'package:shared_preferences/shared_preferences.dart';

abstract class TodoNoteStore {
  Future<List<TodoNote>> load();
  Future<void> save(List<TodoNote> notes);
}

class SharedPreferencesTodoNoteStore implements TodoNoteStore {
  SharedPreferencesTodoNoteStore({SharedPreferences? preferences})
      : _preferences = preferences;

  static const storageKey = 'todo_notes';
  SharedPreferences? _preferences;

  Future<SharedPreferences> get _prefs async =>
      _preferences ??= await SharedPreferences.getInstance();

  @override
  Future<List<TodoNote>> load() async {
    final raw = (await _prefs).getString(storageKey);
    if (raw == null || raw.isEmpty) return [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return [];
      final notes = <TodoNote>[];
      for (final item in decoded) {
        if (item is! Map) continue;
        final note = TodoNote.fromJson(Map<String, dynamic>.from(item));
        if (note != null) notes.add(note);
      }
      return notes;
    } catch (_) {
      return [];
    }
  }

  @override
  Future<void> save(List<TodoNote> notes) async {
    await (await _prefs).setString(
      storageKey,
      jsonEncode([for (final note in notes) note.toJson()]),
    );
  }
}

class MemoryTodoNoteStore implements TodoNoteStore {
  List<TodoNote> notes = [];

  @override
  Future<List<TodoNote>> load() async => List.of(notes);

  @override
  Future<void> save(List<TodoNote> value) async {
    notes = List.of(value);
  }
}
