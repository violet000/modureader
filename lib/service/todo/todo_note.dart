const int todoSummaryNotificationId = 910001;

class TodoNote {
  const TodoNote({
    required this.id,
    required this.notificationId,
    required this.title,
    required this.markdown,
    required this.createdAt,
    required this.cleared,
  });

  final String id;
  final int notificationId;
  final String title;
  final String markdown;
  final DateTime createdAt;
  final bool cleared;

  TodoNote copyWith({
    String? title,
    String? markdown,
    bool? cleared,
  }) {
    return TodoNote(
      id: id,
      notificationId: notificationId,
      title: title ?? this.title,
      markdown: markdown ?? this.markdown,
      createdAt: createdAt,
      cleared: cleared ?? this.cleared,
    );
  }

  Map<String, Object?> toJson() => {
        'id': id,
        'notificationId': notificationId,
        'title': title,
        'markdown': markdown,
        'createdAt': createdAt.toIso8601String(),
        'cleared': cleared,
      };

  static TodoNote? fromJson(Map<String, dynamic> json) {
    final id = json['id'];
    final notificationId = json['notificationId'];
    final title = json['title'];
    final markdown = json['markdown'];
    final createdAt = json['createdAt'];
    final cleared = json['cleared'];
    if (id is! String ||
        id.isEmpty ||
        notificationId is! int ||
        title is! String ||
        markdown is! String ||
        createdAt is! String ||
        cleared is! bool) {
      return null;
    }
    final parsed = DateTime.tryParse(createdAt);
    if (parsed == null) return null;
    return TodoNote(
      id: id,
      notificationId: notificationId,
      title: title,
      markdown: markdown,
      createdAt: parsed,
      cleared: cleared,
    );
  }
}

/// Notes that still belong in the phone notification shade.
List<TodoNote> activeTodoNotes(Iterable<TodoNote> notes) =>
    notes.where((note) => !note.cleared).toList(growable: false);

int nextNotificationId(Iterable<TodoNote> existing) {
  final used = existing.map((note) => note.notificationId).toSet();
  var id = DateTime.now().millisecondsSinceEpoch & 0x7fffffff;
  if (id == 0) id = 1;
  while (used.contains(id) || id == todoSummaryNotificationId) {
    id = (id + 1) & 0x7fffffff;
    if (id == 0) id = 1;
  }
  return id;
}

/// Notification shade text cannot render Markdown.
String todoPlainText(String markdown) {
  var text = markdown.replaceAll(RegExp(r'```[\s\S]*?```'), ' ');
  text = text.replaceAll(RegExp(r'`([^`]*)`'), r'$1');
  text = text.replaceAll(RegExp(r'!\[[^\]]*\]\([^)]*\)'), ' ');
  text = text.replaceAll(RegExp(r'\[([^\]]*)\]\([^)]*\)'), r'$1');
  text = text.replaceAll(RegExp(r'^#{1,6}\s*', multiLine: true), '');
  text = text.replaceAll(
      RegExp(r'^\s*[-*+]\s+\[[ xX]\]\s*', multiLine: true), '');
  text = text.replaceAll(RegExp(r'^\s*[-*+]\s+', multiLine: true), '');
  text = text.replaceAll(RegExp(r'[#>*_~]'), ' ');
  return text.replaceAll(RegExp(r'\s+'), ' ').trim();
}

String todoExcerpt(String markdown, {int max = 80}) {
  final plain = todoPlainText(markdown);
  if (plain.length <= max) return plain;
  return '${plain.substring(0, max)}…';
}
