import 'package:flutter/material.dart';
import '../api.dart';
import 'post_detail_screen.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});
  @override
  State<NotificationsScreen> createState() => NotificationsScreenState();
}

class NotificationsScreenState extends State<NotificationsScreen> with AutomaticKeepAliveClientMixin {
  List<AppNotification> _items = [];
  bool _loading = true;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    refresh();
  }

  Future<void> refresh() async {
    final items = await Api.getNotifications();
    if (!mounted) return;
    setState(() { _items = items; _loading = false; });
  }

  Future<void> _markAllRead() async {
    await Api.markNotificationsRead();
    refresh();
  }

  IconData _iconForType(String type) {
    switch (type) {
      case 'like': return Icons.favorite;
      case 'comment': return Icons.comment;
      case 'security': return Icons.security;
      case 'dm': return Icons.message;
      default: return Icons.notifications;
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('通知'),
        actions: [
          IconButton(onPressed: _markAllRead, icon: const Icon(Icons.done_all), tooltip: '全部已读'),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: refresh,
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _items.isEmpty
                ? const Center(child: Text('暂无通知', style: TextStyle(color: Colors.grey)))
                : ListView.builder(
                    itemCount: _items.length,
                    itemBuilder: (ctx, i) {
                      final n = _items[i];
                      return ListTile(
                        leading: CircleAvatar(
                          backgroundColor: n.read ? Colors.grey[300] : Theme.of(context).colorScheme.primaryContainer,
                          child: Icon(_iconForType(n.type), color: n.read ? Colors.grey : null),
                        ),
                        title: Text(n.title, style: TextStyle(fontWeight: n.read ? FontWeight.normal : FontWeight.bold)),
                        subtitle: n.body.isNotEmpty ? Text(n.body, maxLines: 1, overflow: TextOverflow.ellipsis) : null,
                        trailing: Text(formatTime(n.createdAt), style: const TextStyle(fontSize: 12, color: Colors.grey)),
                        tileColor: n.read ? null : Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.1),
                        onTap: () => _openDetail(n),
                      );
                    },
                  ),
      ),
    );
  }

  void _openDetail(AppNotification n) {
    final from = n.payload['from'] as Map?;
    final fromName = from != null ? (from['display_name'] as String? ?? '用户') : null;
    final postId = n.payload['post_id'] as int?;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(n.title),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (fromName != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text('来自：$fromName', style: TextStyle(fontSize: 12, color: Colors.grey[600])),
              ),
            if (n.body.isNotEmpty)
              Text(n.body, style: const TextStyle(fontSize: 14, height: 1.5)),
            const SizedBox(height: 10),
            Text(formatTime(n.createdAt), style: TextStyle(fontSize: 11, color: Colors.grey[500])),
          ],
        ),
        actions: [
          if (postId != null)
            TextButton(
              onPressed: () {
                Navigator.pop(ctx);
                Navigator.push(context, MaterialPageRoute(builder: (_) => PostDetailScreen(postId: postId)));
              },
              child: const Text('查看动态'),
            ),
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('关闭')),
        ],
      ),
    );
  }
}
