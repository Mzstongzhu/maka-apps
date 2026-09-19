import 'package:flutter/material.dart';
import '../admin_api.dart';
import '../services/version_service.dart';
import '../widgets/update_dialog.dart';

/// 数据概览：协管员可见待处理数；官方管理员可见全站统计
class OverviewScreen extends StatefulWidget {
  const OverviewScreen({super.key});
  @override
  State<OverviewScreen> createState() => _OverviewScreenState();
}

class _OverviewScreenState extends State<OverviewScreen> with AutomaticKeepAliveClientMixin {
  Map<String, dynamic>? _reportStats;
  Map<String, dynamic>? _stats;
  bool _loading = true;
  String? _error;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    final rs = await AdminApi.reportStats();
    Map<String, dynamic>? st;
    if (AdminApi.isOfficial) st = await AdminApi.stats();
    if (!mounted) return;
    setState(() {
      _reportStats = rs;
      _stats = st;
      _loading = false;
    });
  }

  Widget _card(String title, List<(String, String)> items, Color color) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Container(width: 4, height: 18, color: color),
              const SizedBox(width: 8),
              Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
            ]),
            const SizedBox(height: 12),
            Wrap(
              spacing: 24,
              runSpacing: 12,
              children: [
                for (final (label, value) in items)
                  SizedBox(
                    width: 110,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(value, style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: color)),
                        const SizedBox(height: 2),
                        Text(label, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                      ],
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) return Center(child: Text(_error!, style: const TextStyle(color: Colors.red)));

    return ListView(
      children: [
        const SizedBox(height: 8),
        _card('待处理', [
          ('待处理举报', '${_reportStats?['pending_reports'] ?? 0}'),
          ('待审核内容', '${_reportStats?['pending_moderation'] ?? 0}'),
        ], Colors.deepOrange),
        if (_stats != null) ...[
          _card('用户', [
            ('总用户数', '${_stats!['users'] ?? 0}'),
            ('今日新增', '${_stats!['new_users_today'] ?? 0}'),
          ], Theme.of(context).colorScheme.primary),
          _card('内容', [
            ('动态总数', '${_stats!['posts'] ?? 0}'),
            ('今日动态', '${_stats!['posts_today'] ?? 0}'),
            ('群组数', '${_stats!['groups'] ?? 0}'),
            ('海中瓶子', '${_stats!['bottles'] ?? 0}'),
          ], Colors.teal),
        ],
        Card(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: ListTile(
            leading: const Icon(Icons.system_update),
            title: const Text('检查更新'),
            subtitle: const Text('当前版本 ${VersionService.currentVersion}'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => UpdateDialog.check(context, manual: true),
          ),
        ),
        const Padding(
          padding: EdgeInsets.all(16),
          child: Text('协管员仅可处理用户举报；用户管理、内容审核、公告发布仅官方管理员可用。', style: TextStyle(fontSize: 12, color: Colors.grey)),
        ),
      ],
    );
  }
}
