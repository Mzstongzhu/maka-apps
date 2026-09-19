import 'package:flutter/material.dart';
import '../admin_api.dart';
import 'overview_screen.dart';
import 'reports_screen.dart';
import 'users_screen.dart';
import 'moderation_screen.dart';
import 'announcements_screen.dart';
import '../widgets/update_dialog.dart';

/// 管理面板主框架：底部导航按权限显示
/// 协管员：概览 + 举报处理；官方管理员：全部
class AdminHome extends StatefulWidget {
  const AdminHome({super.key});
  @override
  State<AdminHome> createState() => _AdminHomeState();
}

class _AdminHomeState extends State<AdminHome> {
  int _tab = 0;

  @override
  void initState() {
    super.initState();
    // 冷启动自动检查更新（大版本强制 / 小版本可跳过，逻辑与社区版一致）
    WidgetsBinding.instance.addPostFrameCallback((_) => UpdateDialog.check(context));
  }

  @override
  Widget build(BuildContext context) {
    final official = AdminApi.isOfficial;
    final tabs = <(String, IconData, Widget)>[
      ('概览', Icons.dashboard, const OverviewScreen()),
      ('举报', Icons.flag, const ReportsScreen()),
      if (official) ...[
        ('用户', Icons.people, const UsersScreen()),
        ('审核', Icons.rule, const ModerationScreen()),
        ('公告', Icons.campaign, const AnnouncementsScreen()),
      ],
    ];
    final current = tabs[_tab.clamp(0, tabs.length - 1)];

    return Scaffold(
      appBar: AppBar(
        title: const Text('玛卡管理面板'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Center(
              child: Text(
                '${AdminApi.me?.displayName ?? ''} · ${official ? '管理员' : '协管员'}',
                style: const TextStyle(fontSize: 12),
              ),
            ),
          ),
          IconButton(
            tooltip: '退出登录',
            icon: const Icon(Icons.logout),
            onPressed: () async {
              final nav = Navigator.of(context);
              final ok = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('退出登录'),
                  content: const Text('确定要退出管理面板吗？'),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
                    TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('确定')),
                  ],
                ),
              );
              if (ok == true) {
                AdminApi.logout();
                nav.pop();
              }
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async => setState(() {}),
        child: current.$3,
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (i) => setState(() => _tab = i),
        destinations: [
          for (final t in tabs) NavigationDestination(icon: Icon(t.$2), label: t.$1),
        ],
      ),
    );
  }
}
