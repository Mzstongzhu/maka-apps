import 'package:flutter/material.dart';
import '../api.dart';
import '../widgets/bbcode.dart';

class AnnouncementsScreen extends StatefulWidget {
  const AnnouncementsScreen({super.key});
  @override
  State<AnnouncementsScreen> createState() => _AnnouncementsScreenState();
}

class _AnnouncementsScreenState extends State<AnnouncementsScreen> {
  List<Announcement> _items = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    _items = await Api.getAnnouncements();
    if (!mounted) return;
    setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('官方公告')),
      body: RefreshIndicator(
        onRefresh: _load,
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _items.isEmpty
                ? ListView(children: [const SizedBox(height: 120), const Center(child: Text('📢 暂无公告'))])
                : ListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: _items.length,
                    itemBuilder: (_, i) {
                      final a = _items[i];
                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Theme.of(context).cardColor,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: Colors.grey.shade200),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(child: Text(a.title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold))),
                                if (a.pinned)
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                    decoration: BoxDecoration(color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(5)),
                                    child: Text('置顶', style: TextStyle(fontSize: 10, color: Theme.of(context).colorScheme.primary)),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            DefaultTextStyle(
                              style: DefaultTextStyle.of(context).style.copyWith(fontSize: 14, height: 1.5, color: Colors.grey[800]),
                              child: renderBBCode(context, a.content),
                            ),
                            const SizedBox(height: 10),
                            Text('玛卡之声社区 Official · ${formatTime(a.createdAt)}', style: TextStyle(fontSize: 11, color: Colors.grey[500])),
                          ],
                        ),
                      );
                    },
                  ),
      ),
    );
  }
}
