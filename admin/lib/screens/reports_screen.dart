import 'package:flutter/material.dart';
import '../admin_api.dart';
import '../widgets/message_snapshot_view.dart';

/// 举报处理：协管员与管理员均可
class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});
  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> with AutomaticKeepAliveClientMixin {
  List<AdminReport> _items = [];
  bool _pending = true; // true 待处理 / false 已处理
  bool _loading = true;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final (items, err) = await AdminApi.getReports(status: _pending ? 'pending' : 'resolved');
    if (!mounted) return;
    setState(() { _items = items; _loading = false; });
    if (err != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err)));
    }
  }

  String _targetText(AdminReport r) {
    final t = r.target;
    if (t == null) return '（内容已被删除）';
    final content = t['content'] as String? ?? t['display_name'] as String? ?? t['name'] as String? ?? '';
    return content.length > 100 ? '${content.substring(0, 100)}…' : content;
  }

  Future<void> _handle(AdminReport r) async {
    final actions = <(String, IconData, String, String)>[
      if (!r.isMessageReport) ('delete_content', Icons.delete_forever, '删除违规内容', '删除被举报的动态/评论'),
      ('mute_user', Icons.volume_off, '禁言发布者 3 天', '并扣除 20 积分'),
      ('ban_user', Icons.block, '封禁发布者账号', '并扣除 20 积分'),
      ('dismiss', Icons.check_circle_outline, '驳回举报', '经核查未构成违规'),
    ];
    final action = await showModalBottomSheet<String>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(padding: EdgeInsets.all(12), child: Text('选择处理方式', style: TextStyle(fontWeight: FontWeight.bold))),
            for (final (a, icon, label, sub) in actions)
              ListTile(
                leading: Icon(icon),
                title: Text(label),
                subtitle: Text(sub, style: const TextStyle(fontSize: 12)),
                onTap: () => Navigator.pop(ctx, a),
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (action == null) return;
    if (!mounted) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('确认处理'),
        content: Text('确定以「$action」方式处理该举报吗？操作会通知举报人与被举报人。'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('确定')),
        ],
      ),
    );
    if (ok != true) return;
    final err = await AdminApi.handleReport(r.id, action, 'APP 管理面板处理');
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err ?? '已处理')));
    _load();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Column(
      children: [
        SegmentedButton<bool>(
          segments: const [ButtonSegment(value: true, label: Text('待处理')), ButtonSegment(value: false, label: Text('已处理'))],
          selected: {_pending},
          onSelectionChanged: (s) { _pending = s.first; _load(); },
        ).paddingAll(12),
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _items.isEmpty
                  ? Center(child: Text(_pending ? '没有待处理的举报 🎉' : '暂无已处理记录', style: const TextStyle(color: Colors.grey)))
                  : RefreshIndicator(
                      onRefresh: _load,
                      child: ListView.builder(
                        itemCount: _items.length,
                        itemBuilder: (ctx, i) {
                          final r = _items[i];
                          return Card(
                            margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                            child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Chip(
                                        label: Text(r.targetTypeLabel, style: const TextStyle(fontSize: 11)),
                                        visualDensity: VisualDensity.compact,
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          '举报理由：${r.reason}',
                                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                  if (r.description?.isNotEmpty == true)
                                    Padding(
                                      padding: const EdgeInsets.only(top: 6),
                                      child: Text('说明：${r.description}', style: TextStyle(fontSize: 12, color: Colors.grey[700])),
                                    ),
                                  if (r.isMessageReport)
                                    if (r.snapshot != null)
                                      MessageSnapshotView(snapshot: r.snapshot!)
                                    else
                                      Padding(
                                        padding: const EdgeInsets.only(top: 6),
                                        child: Text(_targetText(r), style: const TextStyle(fontSize: 13)),
                                      )
                                  else
                                    Padding(
                                      padding: const EdgeInsets.only(top: 6),
                                      child: Text(_targetText(r), style: const TextStyle(fontSize: 13)),
                                    ),
                                  const SizedBox(height: 6),
                                  Row(
                                    children: [
                                      Text('举报人：${r.reporter?['display_name'] ?? '未知'}', style: TextStyle(fontSize: 11, color: Colors.grey[600])),
                                      if (r.isMessageReport && r.offender != null)
                                        Padding(
                                          padding: const EdgeInsets.only(left: 8),
                                          child: Text('被举报：${r.offender!['display_name']}', style: const TextStyle(fontSize: 11, color: Colors.deepOrange)),
                                        ),
                                      const Spacer(),
                                      if (_pending)
                                        FilledButton.tonal(
                                          onPressed: () => _handle(r),
                                          style: FilledButton.styleFrom(visualDensity: VisualDensity.compact),
                                          child: const Text('处理'),
                                        )
                                      else
                                        Text('已处理', style: TextStyle(fontSize: 11, color: Colors.grey[600])),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
        ),
      ],
    );
  }
}

extension _PaddingX on Widget {
  Widget paddingAll(double v) => Padding(padding: EdgeInsets.all(v), child: this);
}
