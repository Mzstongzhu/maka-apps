import 'package:flutter/material.dart';
import '../api.dart';
import 'activity_detail_screen.dart';

class ActivitiesScreen extends StatefulWidget {
  const ActivitiesScreen({super.key});
  @override
  State<ActivitiesScreen> createState() => _ActivitiesScreenState();
}

class _ActivitiesScreenState extends State<ActivitiesScreen> {
  List<Activity> _items = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    _items = await Api.getActivities();
    if (!mounted) return;
    setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('官方活动')),
      body: RefreshIndicator(
        onRefresh: _load,
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _items.isEmpty
                ? ListView(children: [const SizedBox(height: 120), const Center(child: Text('🎉 暂无活动，敬请期待'))])
                : ListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: _items.length,
                    itemBuilder: (_, i) {
                      final a = _items[i];
                      final (color, label) = switch (a.phase) {
                        ('ongoing') => (Colors.green, '进行中'),
                        ('upcoming') => (Colors.grey, '未开始'),
                        _ => (Colors.red, '已结束'),
                      };
                      return Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        child: Card(
                          elevation: 0,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14), side: BorderSide(color: Colors.grey.shade200)),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(14),
                            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ActivityDetailScreen(activityId: a.id))),
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(child: Text(a.title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold))),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                        decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(6)),
                                        child: Text(label, style: TextStyle(fontSize: 11, color: color)),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  Text(a.content, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 13, color: Colors.grey[600])),
                                  const SizedBox(height: 6),
                                  Text('🕐 ${activityTimeRange(a.startTime, a.endTime)}', style: TextStyle(fontSize: 11, color: Colors.grey[500])),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
      ),
    );
  }
}
