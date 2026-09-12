import 'package:flutter/material.dart';
import '../api.dart';
import '../widgets/bbcode.dart';
import '../widgets/user_tag.dart';

class ActivityDetailScreen extends StatefulWidget {
  final int activityId;
  const ActivityDetailScreen({super.key, required this.activityId});
  @override
  State<ActivityDetailScreen> createState() => _ActivityDetailScreenState();
}

class _ActivityDetailScreenState extends State<ActivityDetailScreen> {
  Activity? _a;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final a = await Api.getActivity(widget.activityId);
    if (!mounted) return;
    setState(() => _a = a);
  }

  Future<void> _signup() async {
    final err = await Api.signupActivity(widget.activityId);
    if (!mounted) return;
    if (err != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err)));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('报名成功！')));
      _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    final a = _a;
    final (color, label) = a == null
        ? (Colors.grey, '')
        : switch (a.phase) {
            ('ongoing') => (Colors.green, '进行中'),
            ('upcoming') => (Colors.grey, '未开始'),
            _ => (Colors.red, '已结束'),
          };
    final canSignup = a != null && !a.signed && a.phase == 'ongoing';
    return Scaffold(
      appBar: AppBar(title: const Text('活动详情')),
      body: a == null
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.all(12),
                children: [
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Theme.of(context).cardColor,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(child: Text(a.title, style: const TextStyle(fontSize: 19, fontWeight: FontWeight.bold))),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(6)),
                              child: Text(label, style: TextStyle(fontSize: 11, color: color)),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text('🕐 ${activityTimeRange(a.startTime, a.endTime)}', style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                        const SizedBox(height: 12),
                        DefaultTextStyle(
                          style: DefaultTextStyle.of(context).style.copyWith(fontSize: 15, height: 1.5),
                          child: renderBBCode(context, a.content),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(child: Text('已有 ${a.signupCount} 人报名', style: TextStyle(color: Colors.grey[600], fontSize: 13))),
                            FilledButton(
                              onPressed: a.signed ? null : canSignup ? _signup : null,
                              child: Text(a.signed ? '✓ 已报名' : a.phase == 'upcoming' ? '未开始' : a.phase == 'ended' ? '已结束' : '立即报名'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Theme.of(context).cardColor,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('报名名单', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                        ...a.signups.map((u) => UserRow(user: u, sub: formatTime(u.createdAt))),
                        if (a.signups.isEmpty)
                          Padding(padding: const EdgeInsets.symmetric(vertical: 12), child: Center(child: Text('还没有人报名', style: TextStyle(color: Colors.grey[500], fontSize: 13)))),
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
