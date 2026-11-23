import 'package:modu_reader/l10n/modu_strings.dart';
import 'package:modu_reader/service/todo/todo_note.dart';
import 'package:modu_reader/service/todo/todo_notes.dart';
import 'package:modu_reader/utils/platform_utils.dart';
import 'package:modu_reader/widgets/common/aurora_chrome.dart';
import 'package:modu_reader/widgets/home_navigation_metrics.dart';
import 'package:modu_reader/widgets/markdown/styled_markdown.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class TodoPage extends StatefulWidget {
  const TodoPage({super.key, this.controller, this.notes});

  final ScrollController? controller;
  final TodoNotes? notes;

  @override
  State<TodoPage> createState() => _TodoPageState();
}

class _TodoPageState extends State<TodoPage> {
  late final TodoNotes _notes = widget.notes ?? TodoNotes.instance;

  @override
  void initState() {
    super.initState();
    _notes.ensureLoaded();
  }

  String t(String cn, String en) => ModuStrings.text(context, cn, en);

  Future<void> _edit([TodoNote? note]) async {
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => TodoEditorPage(notes: _notes, note: note)),
    );
    if (saved == true && mounted) setState(() {});
  }

  Future<void> _clear(TodoNote note) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(t('消除这条待办', 'Clear this todo')),
        content: Text(t(
          '消除后它会从手机通知栏撤下，笔记仍保留在已消除列表。',
          'It leaves the phone notification shade. The note stays in the cleared list.',
        )),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(t('取消', 'Cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(t('消除', 'Clear')),
          ),
        ],
      ),
    );
    if (confirmed == true) await _notes.clear(note.id);
  }

  @override
  Widget build(BuildContext context) {
    final phoneShade = !kIsWeb && AnxPlatform.isMobile;
    return AnimatedBuilder(
      animation: _notes,
      builder: (context, _) {
        final active = _notes.active;
        final cleared = _notes.cleared;
        return Scaffold(
          backgroundColor: Colors.transparent,
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            surfaceTintColor: Colors.transparent,
            title: Text(t('待办', 'Todo')),
          ),
          floatingActionButton: FloatingActionButton.extended(
            onPressed: () => _edit(),
            icon: const Icon(Icons.add),
            label: Text(t('新建笔记', 'New note')),
          ),
          body: ListView(
            controller: widget.controller,
            padding: EdgeInsets.fromLTRB(
              16,
              4,
              16,
              88 + HomeNavigationClearance.of(context),
            ),
            children: [
              if (!phoneShade)
                Padding(
                  padding: const EdgeInsets.fromLTRB(4, 0, 4, 16),
                  child: Text(
                    t('通知栏只在手机上更新。在这里消除后，手机通知会一起撤下。',
                        'The notification shade updates on a phone. Clearing a note here removes it there too.'),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant),
                  ),
                ),
              if (active.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 28),
                  child: Column(children: [
                    const GlowMark(icon: Icons.checklist_rounded, size: 44),
                    const SizedBox(height: 12),
                    Text(
                      t('还没有待办。新建一条 Markdown 笔记后，它会挂在手机通知栏。',
                          'No todos yet. A new Markdown note is pinned to the phone notification shade.'),
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant),
                    ),
                  ]),
                )
              else
                for (final note in active)
                  _TodoTile(
                    note: note,
                    onOpen: () => _edit(note),
                    onClear: () => _clear(note),
                  ),
              if (cleared.isNotEmpty) ...[
                const SizedBox(height: 18),
                Text(t('已消除', 'Cleared'),
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                for (final note in cleared)
                  _TodoTile(
                    note: note,
                    onOpen: () => _openCleared(note),
                    onDelete: () => _notes.delete(note.id),
                  ),
              ],
            ],
          ),
        );
      },
    );
  }

  Future<void> _openCleared(TodoNote note) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => _ClearedNotePage(
          note: note,
          onDelete: () => _notes.delete(note.id),
        ),
      ),
    );
  }
}

class _TodoTile extends StatelessWidget {
  const _TodoTile({
    required this.note,
    required this.onOpen,
    this.onClear,
    this.onDelete,
  });

  final TodoNote note;
  final VoidCallback onOpen;
  final VoidCallback? onClear;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final excerpt = todoExcerpt(note.markdown);
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: scheme.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: scheme.outlineVariant),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: ListTile(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          onTap: onOpen,
          title: Text(note.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                decoration: note.cleared ? TextDecoration.lineThrough : null,
              )),
          subtitle: Text(
            excerpt.isEmpty
                ? DateFormat('MM-dd HH:mm').format(note.createdAt.toLocal())
                : excerpt,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          trailing: onClear != null
              ? IconButton(
                  tooltip: ModuStrings.text(context, '消除', 'Clear'),
                  onPressed: onClear,
                  icon: const Icon(Icons.notifications_off_outlined),
                )
              : IconButton(
                  tooltip: ModuStrings.text(context, '删除', 'Delete'),
                  onPressed: onDelete,
                  icon: const Icon(Icons.delete_outline),
                ),
          ),
        ),
      ),
    );
  }
}

class TodoEditorPage extends StatefulWidget {
  const TodoEditorPage({super.key, required this.notes, this.note});

  final TodoNotes notes;
  final TodoNote? note;

  @override
  State<TodoEditorPage> createState() => _TodoEditorPageState();
}

class _TodoEditorPageState extends State<TodoEditorPage> {
  late final _title = TextEditingController(text: widget.note?.title ?? '');
  late final _markdown =
      TextEditingController(text: widget.note?.markdown ?? '');
  bool _saving = false;

  @override
  void dispose() {
    _title.dispose();
    _markdown.dispose();
    super.dispose();
  }

  String t(String cn, String en) => ModuStrings.text(context, cn, en);

  Future<void> _save() async {
    if (_saving) return;
    if (_title.text.trim().isEmpty) return;
    setState(() => _saving = true);
    final existing = widget.note;
    if (existing == null) {
      final created = await widget.notes.add(
        title: _title.text,
        markdown: _markdown.text,
      );
      if (!mounted) return;
      if (created == null) {
        setState(() => _saving = false);
        return;
      }
    } else {
      await widget.notes.update(
        existing.id,
        title: _title.text,
        markdown: _markdown.text,
      );
    }
    if (mounted) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    final editing = widget.note != null;
    return Scaffold(
      appBar: AppBar(
        title: Text(editing ? t('编辑待办', 'Edit todo') : t('新建待办', 'New todo')),
        actions: [
          TextButton(
            onPressed: _saving ? null : _save,
            child: Text(t('保存', 'Save')),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          TextField(
            controller: _title,
            textInputAction: TextInputAction.next,
            decoration: InputDecoration(
              labelText: t('标题', 'Title'),
              hintText: t('通知栏里显示的标题', 'Title shown in the notification shade'),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _markdown,
            minLines: 10,
            maxLines: 18,
            decoration: InputDecoration(
              alignLabelWithHint: true,
              labelText: t('Markdown 笔记', 'Markdown note'),
              hintText: t('支持标题、列表和任务勾选，例如：\n- [ ] 读完第三章',
                  'Headings, lists and tasks, for example:\n- [ ] Finish chapter 3'),
            ),
          ),
        ],
      ),
    );
  }
}

class _ClearedNotePage extends StatelessWidget {
  const _ClearedNotePage({required this.note, required this.onDelete});

  final TodoNote note;
  final Future<void> Function() onDelete;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(note.title),
        actions: [
          IconButton(
            tooltip: ModuStrings.text(context, '删除', 'Delete'),
            onPressed: () async {
              await onDelete();
              if (context.mounted) Navigator.pop(context);
            },
            icon: const Icon(Icons.delete_outline),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (note.markdown.isEmpty)
            Text(ModuStrings.text(context, '这条笔记没有正文。', 'This note has no body.'))
          else
            StyledMarkdown(data: note.markdown),
        ],
      ),
    );
  }
}
