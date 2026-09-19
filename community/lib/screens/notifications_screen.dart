import 'package:flutter/material.dart';
import '../api.dart';
import 'post_detail_screen.dart';
import 'user_profile_screen.dart';
import 'friends_screen.dart';
import 'dm_requests_screen.dart';
import 'chat_group_screen.dart';

/// 通知消息（消息页内置入口，不再是独立 tab）。进入页面即标记全部已读。
class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});
  @override
  State<NotificationsScreen> createState() => NotificationsScreenState();
}

class NotificationsScreenState extends State<NotificationsScreen> {
  List<AppNotification> _items = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    refresh(markRead: true);
  }

  Future<void> refresh({bool markRead = false}) async {
    if (markRead) {
      await Api.markNotificationsRead();
    }
    final items = await Api.getNotifications();
    if (!mounted) return;
    setState(() { _items = items; _loading = false; });
  }

  IconData _iconForType(String type) {
    switch (type) {
      case 'like': return Icons.favorite;
      case 'comment': return Icons.comment;
      case 'mention': return Icons.alternate_email;
      case 'security': return Icons.security;
      case 'dm': return Icons.message;
      case 'friend_request': return Icons.person_add_alt;
      case 'friend_accept': return Icons.people_alt;
      case 'dm_request': return Icons.mail_outline;
      case 'dm_accept': return Icons.mark_email_read_outlined;
      case 'chat_invite': return Icons.group_add;
      case 'chat_kicked': return Icons.group_remove;
      case 'system': return Icons.campaign_outlined;
      default: return Icons.notifications;
    }
  }

  Color? _colorForType(String type) {
    switch (type) {
      case 'like': return Colors.pink;
      case 'comment': return Colors.blue;
      case 'mention': return Colors.purple;
      case 'security': return Colors.orange;
      case 'friend_request':
      case 'dm_request':
      case 'chat_invite':
        return Colors.green;
      default: return null;
    }
  }

  void _route(AppNotification n) {
    final target = n.target;
    final kind = target?['kind'] as String?;
    final id = target?['id'] is int ? target!['id'] as int : int.tryParse('${target?['id']}') ;
    switch (kind) {
      case 'post':
        if (id != null) {
          Navigator.push(context, MaterialPageRoute(builder: (_) => PostDetailScreen(postId: id)));
          return;
        }
        break;
      case 'user':
        if (id != null) {
          Navigator.push(context, MaterialPageRoute(builder: (_) => UserProfileScreen(userId: id)));
          return;
        }
        break;
      case 'friend_requests':
        Navigator.push(context, MaterialPageRoute(builder: (_) => const FriendsScreen(initialTab: 1)));
        return;
      case 'dm_requests':
        Navigator.push(context, MaterialPageRoute(builder: (_) => const DmRequestsScreen()));
        return;
      case 'chat':
        if (id != null) {
          Navigator.push(context, MaterialPageRoute(
              builder: (_) => ChatGroupScreen(groupId: id, groupName: '群组$id')));
          return;
        }
        break;
    }
    _openDetail(n);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('通知消息'),
        actions: [
          IconButton(onPressed: () => refresh(markRead: true), icon: const Icon(Icons.done_all), tooltip: '全部已读'),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => refresh(),
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _items.isEmpty
                ? ListView(children: const [SizedBox(height: 200), Center(child: Text('暂无通知', style: TextStyle(color: Colors.grey)))])
                : ListView.builder(
                    itemCount: _items.length,
                    itemBuilder: (ctx, i) {
                      final n = _items[i];
                      final color = _colorForType(n.type);
                      return ListTile(
                        leading: CircleAvatar(
                          backgroundColor: (color ?? Theme.of(context).colorScheme.primary).withValues(alpha: 0.12),
                          child: Icon(_iconForType(n.type), color: color ?? Theme.of(context).colorScheme.primary, size: 20),
                        ),
                        title: Text(n.title, style: TextStyle(fontWeight: n.read ? FontWeight.normal : FontWeight.bold, fontSize: 14)),
                        subtitle: n.body.isNotEmpty ? Text(n.body, maxLines: 2, overflow: TextOverflow.ellipsis) : null,
                        trailing: Text(formatTime(n.createdAt), style: const TextStyle(fontSize: 12, color: Colors.grey)),
                        tileColor: n.read ? null : Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.1),
                        onTap: () => _route(n),
                      );
                    },
                  ),
      ),
    );
  }

  void _openDetail(AppNotification n) {
    final from = n.payload['from'] as Map?;
    final fromName = from != null ? (from['display_name'] as String? ?? '用户') : null;
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
                child: Text('来自：$fromName', style: const TextStyle(fontSize: 12, color: Colors.grey)),
              ),
            if (n.body.isNotEmpty)
              Text(n.body, style: const TextStyle(fontSize: 14, height: 1.5)),
            const SizedBox(height: 10),
            Text(formatTime(n.createdAt), style: const TextStyle(fontSize: 11, color: Colors.grey)),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('关闭')),
        ],
      ),
    );
  }
}
