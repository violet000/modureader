import 'package:modu_reader/page/home_page/todo_page.dart';
import 'package:modu_reader/service/todo/todo_note.dart';
import 'package:modu_reader/service/todo/todo_notes.dart';
import 'package:modu_reader/service/todo/todo_shade.dart';
import 'package:modu_reader/service/todo/todo_store.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _RecordingShade implements TodoShade {
  final syncs = <List<TodoNote>>[];

  @override
  Future<void> sync(List<TodoNote> notes) async {
    syncs.add(List.of(notes));
  }
}

void main() {
  test('markdown becomes a single notification line', () {
    expect(
      todoPlainText('# 买书\n\n- [ ] 读完第三章\n\n`code`'),
      '买书 读完第三章 code',
    );
    expect(todoExcerpt('word ' * 40).endsWith('…'), isTrue);
  });

  test('notification ids skip the summary slot', () {
    final occupied = TodoNote(
      id: 'a',
      notificationId: todoSummaryNotificationId - 1,
      title: 'a',
      markdown: '',
      createdAt: DateTime.utc(2026),
      cleared: false,
    );
    expect(nextNotificationId([occupied]), isNot(todoSummaryNotificationId));
  });

  test('store keeps cleared notes out of a fresh load', () async {
    SharedPreferences.setMockInitialValues({});
    final store = SharedPreferencesTodoNoteStore();
    final note = TodoNote(
      id: '1',
      notificationId: 7,
      title: '记一下',
      markdown: '- [ ] 明天读',
      createdAt: DateTime.utc(2026, 11, 23),
      cleared: true,
    );
    await store.save([note]);
    final loaded = await store.load();
    expect(loaded, hasLength(1));
    expect(loaded.single.cleared, isTrue);
    expect(activeTodoNotes(loaded), isEmpty);
  });

  testWidgets('clearing a note drops it from the shade payload', (tester) async {
    final shade = _RecordingShade();
    final notes = TodoNotes(store: MemoryTodoNoteStore(), shade: shade);
    await tester.pumpWidget(MaterialApp(
      locale: const Locale('en'),
      home: TodoPage(notes: notes),
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.text('New note'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, 'Read chapter 3');
    await tester.enterText(find.byType(TextField).last, '- [ ] finish the notes');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(find.text('Read chapter 3'), findsOneWidget);
    expect(activeTodoNotes(shade.syncs.last), hasLength(1));

    await tester.tap(find.byTooltip('Clear'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Clear'));
    await tester.pumpAndSettle();

    expect(activeTodoNotes(shade.syncs.last), isEmpty);
    expect(shade.syncs.last.single.cleared, isTrue);
    expect(find.text('Cleared'), findsOneWidget);
    expect(find.text('Read chapter 3'), findsOneWidget);
  });
}
