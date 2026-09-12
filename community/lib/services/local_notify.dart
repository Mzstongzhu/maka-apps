import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// 系统级本地通知：收到私信/社区通知时弹出系统通知栏消息
class LocalNotify {
  static final _plugin = FlutterLocalNotificationsPlugin();
  static bool _inited = false;

  static const _dmChannel = AndroidNotificationChannel(
    'dm', '私信消息', description: '收到新私信时的提醒',
    importance: Importance.high,
  );
  static const _notifyChannel = AndroidNotificationChannel(
    'notify', '社区通知', description: '点赞、评论、公告等社区通知',
    importance: Importance.defaultImportance,
  );

  static Future<void> init() async {
    if (_inited) return;
    const settings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
    );
    await _plugin.initialize(settings);
    final impl = _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    // Android 13+ 运行时权限
    await impl?.requestNotificationsPermission();
    await impl?.createNotificationChannel(_dmChannel);
    await impl?.createNotificationChannel(_notifyChannel);
    _inited = true;
  }

  /// channel: 'dm'（私信）/ 'notify'（社区通知）
  static Future<void> show(String channel, String title, String body) async {
    if (!_inited) return;
    final details = NotificationDetails(
      android: AndroidNotificationDetails(
        channel,
        channel == 'dm' ? _dmChannel.name : _notifyChannel.name,
        channelDescription: channel == 'dm' ? _dmChannel.description : _notifyChannel.description,
        importance: Importance.high,
        priority: Priority.high,
        channelShowBadge: true,
        onlyAlertOnce: false,
      ),
    );
    final id = DateTime.now().millisecondsSinceEpoch % 0x7fffffff;
    try {
      await _plugin.show(id, title, body.isEmpty ? null : body, details);
    } catch (_) {}
  }
}
