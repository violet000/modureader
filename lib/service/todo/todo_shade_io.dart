import 'package:modu_reader/service/todo/todo_note.dart';
import 'package:modu_reader/service/todo/todo_shade.dart';
import 'package:modu_reader/utils/log/common.dart';
import 'package:modu_reader/utils/platform_utils.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

TodoShade createTodoShade() => MobileTodoShade();

class MobileTodoShade implements TodoShade {
  MobileTodoShade({FlutterLocalNotificationsPlugin? plugin})
      : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  static const _channelId = 'com.modu.reader.todo';
  static const _channelName = '待办笔记';
  static const _groupKey = 'com.modu.reader.todo.group';

  final FlutterLocalNotificationsPlugin _plugin;
  final Set<int> _posted = {};
  bool _ready = false;

  bool get _supported => AnxPlatform.isAndroid || AnxPlatform.isIOS;

  @override
  Future<void> sync(List<TodoNote> notes) async {
    if (!_supported) return;
    if (notes.isEmpty && _posted.isEmpty) return;
    try {
      await _ensureReady();
      final active = activeTodoNotes(notes);
      final activeIds = active.map((note) => note.notificationId).toSet();
      final known = {..._posted, ...notes.map((note) => note.notificationId)};
      for (final id in known.difference(activeIds)) {
        await _plugin.cancel(id);
      }
      for (final note in active) {
        await _plugin.show(
          note.notificationId,
          note.title,
          todoExcerpt(note.markdown).isEmpty
              ? note.title
              : todoExcerpt(note.markdown),
          _itemDetails(grouped: active.length > 1),
          payload: note.id,
        );
      }
      if (active.length > 1 && AnxPlatform.isAndroid) {
        await _plugin.show(
          todoSummaryNotificationId,
          '待办',
          '${active.length} 条未消除',
          _summaryDetails(active),
        );
      } else {
        await _plugin.cancel(todoSummaryNotificationId);
      }
      _posted
        ..clear()
        ..addAll(activeIds);
    } catch (error) {
      AnxLog.warning('Todo notification sync failed: $error');
    }
  }

  Future<void> _ensureReady() async {
    if (_ready) return;
    const settings = InitializationSettings(
      android: AndroidInitializationSettings('@drawable/ic_stat_read_aloud'),
      iOS: DarwinInitializationSettings(
        requestAlertPermission: false,
        requestBadgePermission: false,
        requestSoundPermission: false,
      ),
    );
    await _plugin.initialize(settings);
    if (AnxPlatform.isAndroid) {
      await _plugin
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.requestNotificationsPermission();
    }
    if (AnxPlatform.isIOS) {
      await _plugin
          .resolvePlatformSpecificImplementation<
              IOSFlutterLocalNotificationsPlugin>()
          ?.requestPermissions(alert: true, badge: false, sound: false);
    }
    _ready = true;
  }

  NotificationDetails _itemDetails({required bool grouped}) {
    return NotificationDetails(
      android: AndroidNotificationDetails(
        _channelId,
        _channelName,
        channelDescription: '未消除的 Markdown 待办会留在通知栏',
        importance: Importance.high,
        priority: Priority.high,
        ongoing: true,
        autoCancel: false,
        onlyAlertOnce: true,
        playSound: false,
        enableVibration: false,
        category: AndroidNotificationCategory.reminder,
        groupKey: grouped ? _groupKey : null,
        groupAlertBehavior: GroupAlertBehavior.children,
        icon: '@drawable/ic_stat_read_aloud',
      ),
      iOS: const DarwinNotificationDetails(
        presentAlert: true,
        presentBanner: true,
        presentList: true,
        presentSound: false,
        presentBadge: false,
        threadIdentifier: 'modu-todo',
      ),
    );
  }

  NotificationDetails _summaryDetails(List<TodoNote> active) {
    final lines = [
      for (final note in active.take(5)) note.title,
      if (active.length > 5) '还有 ${active.length - 5} 条',
    ];
    return NotificationDetails(
      android: AndroidNotificationDetails(
        _channelId,
        _channelName,
        channelDescription: '未消除的 Markdown 待办会留在通知栏',
        importance: Importance.high,
        priority: Priority.high,
        ongoing: true,
        autoCancel: false,
        onlyAlertOnce: true,
        playSound: false,
        enableVibration: false,
        setAsGroupSummary: true,
        groupKey: _groupKey,
        groupAlertBehavior: GroupAlertBehavior.children,
        icon: '@drawable/ic_stat_read_aloud',
        styleInformation: InboxStyleInformation(
          lines,
          contentTitle: '待办',
          summaryText: '${active.length} 条未消除',
        ),
      ),
    );
  }
}
