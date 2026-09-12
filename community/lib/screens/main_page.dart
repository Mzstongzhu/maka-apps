import 'dart:async';
import 'package:flutter/material.dart';
import '../api.dart';
import '../services/local_notify.dart';
import 'home_screen.dart';
import 'conversations.dart';
import 'notifications_screen.dart';
import 'profile.dart';
import 'chat.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});
  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _tabIndex = 0;
  User? _user;
  int _unreadNotify = 0;
  int _unreadDm = 0;
  StreamSubscription? _dmSub;
  StreamSubscription? _sentSub;
  StreamSubscription? _readSub;
  StreamSubscription? _notifySub;
  final _convKey = GlobalKey<ConversationsScreenState>();
  final _notifyKey = GlobalKey<NotificationsScreenState>();
  final _homeKey = GlobalKey<HomeScreenState>();

  @override
  void initState() {
    super.initState();
    _validateAndConnect();
    LocalNotify.init();
    _dmSub = SocketService.dmStream.listen((msg) {
      setState(() => _unreadDm++);
      _convKey.currentState?.refresh();
      // 系统通知栏弹出私信提醒
      LocalNotify.show('dm', '新私信', (msg['content'] as String?) ?? '');
    });
    // 自己发出消息：刷新会话列表（新会话/最后一条预览），不增加未读角标
    _sentSub = SocketService.sentStream.listen((msg) {
      _convKey.currentState?.refresh();
    });
    // 已读回执：刷新会话列表
    _readSub = SocketService.readStream.listen((data) {
      _convKey.currentState?.refresh();
    });
    _notifySub = SocketService.notifyStream.listen((n) {
      final type = n['type'] as String?;
      // 私信走消息模块（dm:new 已单独提醒），不进通知角标/列表
      if (type == 'dm') return;
      setState(() => _unreadNotify++);
      _notifyKey.currentState?.refresh();
      final payload = (n['payload'] as Map?)?.cast<String, dynamic>() ?? {};
      LocalNotify.show('notify', payload['title'] as String? ?? '社区通知', payload['content'] as String? ?? payload['excerpt'] as String? ?? '');
    });
  }

  Future<void> _validateAndConnect() async {
    final u = await Api.getMe();
    if (!mounted) return;
    if (u == null) {
      await Api.clearToken();
      Navigator.pushReplacementNamed(context, '/login');
    } else {
      setState(() => _user = u);
      SocketService.connect(Api.token!);
    }
  }

  @override
  void dispose() {
    _dmSub?.cancel();
    _sentSub?.cancel();
    _readSub?.cancel();
    _notifySub?.cancel();
    super.dispose();
  }

  void _openChat(int peerId, String peerName) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => ChatScreen(peerId: peerId, peerName: peerName)))
        .then((_) {
      // 从会话返回：刷新列表（清未读、更新预览）并清掉角标
      _convKey.currentState?.refresh();
      if (_tabIndex == 1 && mounted) setState(() => _unreadDm = 0);
    });
  }

  @override
  Widget build(BuildContext context) {
    final tabs = [
      HomeScreen(key: _homeKey),
      ConversationsScreen(key: _convKey, onOpenChat: _openChat),
      NotificationsScreen(key: _notifyKey),
      ProfileScreen(user: _user),
    ];
    return Scaffold(
      body: IndexedStack(index: _tabIndex, children: tabs),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tabIndex,
        onDestinationSelected: (i) => setState(() {
          _tabIndex = i;
          if (i == 0) {
            _unreadDm = 0;
            _homeKey.currentState?.refresh();
          }
          if (i == 1) _unreadDm = 0;
          if (i == 2) _unreadNotify = 0;
        }),
        destinations: [
          const NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home), label: '首页'),
          NavigationDestination(
            icon: Badge(label: _unreadDm > 0 ? Text('$_unreadDm') : null, child: const Icon(Icons.chat)),
            selectedIcon: const Icon(Icons.chat),
            label: '消息',
          ),
          NavigationDestination(
            icon: Badge(label: _unreadNotify > 0 ? Text('$_unreadNotify') : null, child: const Icon(Icons.notifications)),
            selectedIcon: const Icon(Icons.notifications),
            label: '通知',
          ),
          const NavigationDestination(icon: Icon(Icons.person), selectedIcon: Icon(Icons.person), label: '我的'),
        ],
      ),
    );
  }
}
