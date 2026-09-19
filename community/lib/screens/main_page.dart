import 'dart:async';
import 'package:flutter/material.dart';
import '../api.dart';
import '../services/local_notify.dart';
import '../services/version_service.dart';
import '../widgets/update_dialog.dart';
import 'home_screen.dart';
import 'conversations.dart';
import 'features_screen.dart';
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
  int _unreadMsg = 0;
  StreamSubscription? _dmSub;
  StreamSubscription? _sentSub;
  StreamSubscription? _readSub;
  StreamSubscription? _notifySub;
  StreamSubscription? _chatSub;
  final _convKey = GlobalKey<ConversationsScreenState>();
  final _homeKey = GlobalKey<HomeScreenState>();

  @override
  void initState() {
    super.initState();
    _validateAndConnect();
    LocalNotify.init();
    _dmSub = SocketService.dmStream.listen((msg) {
      _convKey.currentState?.refresh();
      // 系统通知栏弹出私信提醒
      LocalNotify.show('dm', '新私信', (msg['content'] as String?) ?? '');
    });
    // 自己发出消息：刷新会话列表（新会话/最后一条预览）
    _sentSub = SocketService.sentStream.listen((msg) {
      _convKey.currentState?.refresh();
    });
    // 已读回执：刷新会话列表
    _readSub = SocketService.readStream.listen((data) {
      _convKey.currentState?.refresh();
    });
    _notifySub = SocketService.notifyStream.listen((n) {
      final type = n['type'] as String?;
      // 私信走消息模块（dm:new 已单独提醒），不弹系统通知栏
      if (type == 'dm') return;
      _convKey.currentState?.refresh();
      final payload = (n['payload'] as Map?)?.cast<String, dynamic>() ?? {};
      LocalNotify.show('notify', payload['title'] as String? ?? '社区通知', payload['content'] as String? ?? payload['excerpt'] as String? ?? '');
    });
    // 聊天群组消息：刷新列表与底部角标（会话页内部自行渲染消息）
    _chatSub = SocketService.chatMsgStream.listen((msg) {
      _convKey.currentState?.refresh();
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
      // 登录后自动检查更新（延迟等首屏渲染完成）；大版本强制、小版本可跳过
      Future.delayed(const Duration(milliseconds: 800), () {
        if (mounted) {
          UpdateDialog.check(context, currentVersion: VersionService.currentVersion);
        }
      });
    }
  }

  @override
  void dispose() {
    _dmSub?.cancel();
    _sentSub?.cancel();
    _readSub?.cancel();
    _notifySub?.cancel();
    _chatSub?.cancel();
    super.dispose();
  }

  void _openChat(int peerId, String peerName) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => ChatScreen(peerId: peerId, peerName: peerName)))
        .then((_) {
      // 从会话返回：刷新列表（清未读、更新预览、同步角标）
      _convKey.currentState?.refresh();
    });
  }

  void _syncBadge() {
    final total = _convKey.currentState?.unreadTotal ?? 0;
    if (total != _unreadMsg) setState(() => _unreadMsg = total);
  }

  @override
  Widget build(BuildContext context) {
    final tabs = [
      HomeScreen(key: _homeKey),
      ConversationsScreen(key: _convKey, onOpenChat: _openChat, onChanged: _syncBadge),
      const FeaturesScreen(),
      ProfileScreen(user: _user),
    ];
    return Scaffold(
      body: IndexedStack(index: _tabIndex, children: tabs),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tabIndex,
        onDestinationSelected: (i) => setState(() {
          _tabIndex = i;
          if (i == 0) _homeKey.currentState?.refresh();
          if (i == 1) _convKey.currentState?.refresh();
        }),
        destinations: [
          const NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home), label: '首页'),
          NavigationDestination(
            icon: Badge(label: _unreadMsg > 0 ? Text(_unreadMsg > 99 ? '99+' : '$_unreadMsg') : null, child: const Icon(Icons.chat_outlined)),
            selectedIcon: const Icon(Icons.chat),
            label: '消息',
          ),
          const NavigationDestination(
            icon: Icon(Icons.apps_outlined),
            selectedIcon: Icon(Icons.apps),
            label: '功能',
          ),
          const NavigationDestination(icon: Icon(Icons.person_outline), selectedIcon: Icon(Icons.person), label: '我的'),
        ],
      ),
    );
  }
}
