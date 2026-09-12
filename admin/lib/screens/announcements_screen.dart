import 'package:flutter/material.dart';
import '../admin_api.dart';

/// 公告管理：仅官方管理员
class AnnouncementsScreen extends StatefulWidget {
  const AnnouncementsScreen({super.key});
  @override
  State<AnnouncementsScreen> createState() => _AnnouncementsScreenState();
}

class _AnnouncementsScreenState extends State<AnnouncementsScreen> with AutomaticKeepAliveClientMixin {
  List<Map<String, dynamic>> _items = [];
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
    final (items, err) = await AdminApi.getAnnouncements();
    if (!mounted) return;
    setState(() { _items = items; _loading = false; });
    if (err != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err)));
    }
  }

  Future<void> _create() async {
    final titleCtrl = TextEditingController();
    final contentCtrl = TextEditingController();
    bool pinned = false;
    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: const Text('发布公告'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: titleCtrl, maxLength: 40, decoration: const InputDecoration(labelText: '标题', counterText: '')),
              const SizedBox(height: 8),
              TextField(controller: contentCtrl, maxLines: 5, maxLength: 2000, decoration: const InputDecoration(labelText: '内容', alignLabelWithHint: true)),
              CheckboxListTile(
                value: pinned,
                onChanged: (v) => setLocal(() => pinned = v ?? false),
                title: const Text('置顶公告', style: TextStyle(fontSize: 14)),
                controlAffinity: ListTileControlAffinity.leading,
                contentPadding: EdgeInsets.zero,
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
            TextButton(
              onPressed: () async {
                final title = titleCtrl.text.trim();
                final content = contentCtrl.text.trim();
                if (title.isEmpty || content.isEmpty) return;
                Navigator.pop(ctx);
                final err = await AdminApi.createAnnouncement(title, content, pinned);
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err ?? '公告已发布')));
                _load();
              },
              child: const Text('发布'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Stack(
      children: [
        _loading
            ? const Center(child: CircularProgressIndicator())
            : _items.isEmpty
                ? const Center(child: Text('暂无公告', style: TextStyle(color: Colors.grey)))
                : ListView.builder(
                    itemCount: _items.length,
                    itemBuilder: (ctx, i) {
                      final a = _items[i];
                      final content = a['content'] as String? ?? '';
                      final excerpt = content.length > 80 ? '${content.substring(0, 80)}…' : content;
                      return ListTile(
                        leading: const Icon(Icons.campaign),
                        title: Text(a['title'] as String? ?? '', style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text(excerpt, maxLines: 2, overflow: TextOverflow.ellipsis),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete_outline, color: Colors.red),
                          tooltip: '删除公告',
                          onPressed: () async {
                            final ok = await showDialog<bool>(
                              context: context,
                              builder: (c) => AlertDialog(
                                title: const Text('删除公告'),
                                content: const Text('确定删除该公告吗？'),
                                actions: [
                                  TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('取消')),
                                  TextButton(onPressed: () => Navigator.pop(c, true), child: const Text('确定')),
                                ],
                              ),
                            );
                            if (ok != true) return;
                            final id = (a['id'] as num).toInt();
                            final err = await AdminApi.deleteAnnouncement(id);
                            if (!mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err ?? '已删除')));
                            _load();
                          },
                        ),
                      );
                    },
                  ),
        Positioned(
          right: 16,
          bottom: 16,
          child: FloatingActionButton.extended(
            onPressed: _create,
            icon: const Icon(Icons.add),
            label: const Text('发布'),
          ),
        ),
      ],
    );
  }
}
