import 'dart:async';
import 'package:flutter/material.dart';
import '../api.dart';
import 'new_chat.dart';
import 'notifications_screen.dart';
import 'dm_requests_screen.dart';
import 'chat_group_screen.dart';

/// 统一消息行（私信或聊天群）
class _Row {
  final bool isGroup;
  final Conversation? dm;
  final ChatGroup? group;
  _Row.dm(Conversation c) : isGroup = false, dm = c, group = null;
  _Row.group(ChatGroup g) : isGroup = true, dm = null, group = g;

  int get time => isGroup ? group!.lastMsgAt : dm!.lastTime;
  int get unread => isGroup ? group!.unread : dm!.unread;
  String get title => isGroup ? group!.name : dm!.peerName;
  String get preview {
    if (isGroup) return group!.lastPreview;
    final p = dm!.lastPreview;
    return p.isEmpty ? '' : (dm!.lastFromMe ? '我: $p' : p);
  }
}

class ConversationsScreen extends StatefulWidget {
  final void Function(int peerId, String peerName)? onOpenChat;

  /// 列表/未读数刷新后回调（供主框架同步底部角标）
  final VoidCallback? onChanged;
  const ConversationsScreen({super.key, this.onOpenChat, this.onChanged});
  @override
  State<ConversationsScreen> createState() => ConversationsScreenState();
}

class ConversationsScreenState extends State<ConversationsScreen> with AutomaticKeepAliveClientMixin {
  List<Conversation> _items = [];
  List<ChatGroup> _groups = [];
  UnreadCount _unread = UnreadCount();
  bool _loading = true;
  StreamSubscription? _chatMsgSub;
  Timer? _refreshDebounce;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    refresh();
    // 群消息到达时刷新列表（预览/未读/排序）
    _chatMsgSub = SocketService.chatMsgStream.listen((_) {
      _refreshDebounce?.cancel();
      _refreshDebounce = Timer(const Duration(milliseconds: 500), refresh);
    });
  }

  @override
  void dispose() {
    _chatMsgSub?.cancel();
    _refreshDebounce?.cancel();
    super.dispose();
  }

  Future<void> refresh() async {
    final results = await Future.wait([
      Api.getConversations(),
      Api.getUnreadCount(),
      Api.getChatGroups(),
    ]);
    if (!mounted) return;
    setState(() {
      _items = results[0] as List<Conversation>;
      _unread = results[1] as UnreadCount;
      _groups = results[2] as List<ChatGroup>;
      _loading = false;
    });
    widget.onChanged?.call();
  }

  /// 底部 tab 角标：通知 + 私信 + 群聊 + 消息申请 的总未读
  int get unreadTotal => _unread.total;

  Future<void> _openNewChat() async {
    await Navigator.push(context, MaterialPageRoute(
      builder: (_) => NewChatScreen(onPick: (id, name) => widget.onOpenChat?.call(id, name)),
    ));
    if (mounted) refresh();
  }

  Future<void> _openNotifications() async {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => const NotificationsScreen()));
    refresh();
  }

  Future<void> _openDmRequests() async {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => const DmRequestsScreen()));
    refresh();
  }

  Future<void> _openGroup(ChatGroup g) async {
    await Navigator.push(context, MaterialPageRoute(
      builder: (_) => ChatGroupScreen(groupId: g.id, groupName: g.name),
    ));
    if (mounted) refresh();
  }

  Widget _pinnedRow(IconData icon, Color color, String title, String subtitle, int badge, VoidCallback onTap) {
    return ListTile(
      leading: CircleAvatar(
        radius: 24,
        backgroundColor: color.withValues(alpha: 0.12),
        child: Icon(icon, color: color),
      ),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
      subtitle: Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12)),
      trailing: badge > 0
          ? Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(color: Colors.red, borderRadius: BorderRadius.circular(11)),
              child: Text(badge > 99 ? '99+' : '$badge', style: const TextStyle(color: Colors.white, fontSize: 12)),
            )
          : const Icon(Icons.chevron_right, color: Colors.grey),
      onTap: onTap,
    );
  }

  Widget _rowTile(_Row r) {
    final bold = r.unread > 0;
    final timeText = r.time > 0 ? formatTime(r.time) : '';
    final leading = r.isGroup
        ? CircleAvatar(
            backgroundColor: Colors.teal.shade100,
            child: const Icon(Icons.groups, color: Colors.teal),
          )
        : CircleAvatar(
            backgroundColor: Theme.of(context).colorScheme.primaryContainer,
            child: Text(r.title.isNotEmpty ? r.title[0] : '?'),
          );
    return ListTile(
      leading: leading,
      title: Text(r.title, style: TextStyle(fontWeight: bold ? FontWeight.bold : FontWeight.normal),
          maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: r.preview.isEmpty
          ? null
          : Text(r.preview, maxLines: 1, overflow: TextOverflow.ellipsis,
              style: TextStyle(color: bold ? null : Colors.grey)),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(timeText, style: const TextStyle(fontSize: 12, color: Colors.grey)),
          if (r.unread > 0)
            Container(
              margin: const EdgeInsets.only(top: 4),
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
              decoration: BoxDecoration(color: Colors.red, borderRadius: BorderRadius.circular(10)),
              child: Text(r.unread > 99 ? '99+' : '${r.unread}',
                  style: const TextStyle(color: Colors.white, fontSize: 11)),
            ),
        ],
      ),
      onTap: () {
        if (r.isGroup) {
          _openGroup(r.group!);
        } else {
          widget.onOpenChat?.call(r.dm!.peerId, r.dm!.peerName);
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final rows = <_Row>[
      ..._items.map(_Row.dm),
      ..._groups.map(_Row.group),
    ]..sort((a, b) => b.time.compareTo(a.time));

    return Scaffold(
      appBar: AppBar(
        title: const Text('消息'),
        actions: [
          IconButton(
            tooltip: '发起私信 / 群组',
            icon: const Icon(Icons.edit_square),
            onPressed: _openNewChat,
          ),
        ],
      ),
      floatingActionButton: _loading || rows.isNotEmpty
          ? null
          : FloatingActionButton.extended(
              onPressed: _openNewChat,
              icon: const Icon(Icons.edit_square),
              label: const Text('发起聊天'),
            ),
      body: RefreshIndicator(
        onRefresh: refresh,
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                children: [
                  _pinnedRow(Icons.notifications, Colors.deepPurple, '通知消息',
                      '点赞、评论、@、好友申请等', _unread.notify, _openNotifications),
                  _pinnedRow(Icons.mail_outline, Colors.orange, '消息申请',
                      '陌生人发起的私信，确认后可继续聊天', _unread.dmRequest, _openDmRequests),
                  const Divider(height: 1),
                  if (rows.isEmpty)
                    const Padding(
                      padding: EdgeInsets.only(top: 120),
                      child: Center(child: Text('暂无消息，点击右上角按钮发起', style: TextStyle(color: Colors.grey))),
                    )
                  else
                    ...rows.map(_rowTile),
                ],
              ),
      ),
    );
  }
}
