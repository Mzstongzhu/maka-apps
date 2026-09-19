import 'package:flutter/material.dart';
import '../api.dart';
import '../widgets/avatar.dart';
import 'user_profile_screen.dart';
import 'chat.dart';

/// 我的好友 / 好友申请，三分区：好友 / 收到的申请 / 发出的申请
class FriendsScreen extends StatefulWidget {
  /// 初始分区：0=好友 1=收到的申请 2=发出的申请
  final int initialTab;
  const FriendsScreen({super.key, this.initialTab = 0});
  @override
  State<FriendsScreen> createState() => FriendsScreenState();
}

class FriendsScreenState extends State<FriendsScreen> with SingleTickerProviderStateMixin {
  late final TabController _tab;
  List<User> _friends = [];
  List<FriendRequest> _incoming = [];
  List<FriendRequest> _outgoing = [];
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 3, vsync: this, initialIndex: widget.initialTab.clamp(0, 2));
    _refreshAll();
  }

  Future<void> _refreshAll() async {
    final (f, i, o) = await (Api.getFriends(), Api.getIncomingFriends(), Api.getOutgoingFriends()).wait;
    if (!mounted) return;
    setState(() {
      _friends = f;
      _incoming = i;
      _outgoing = o;
    });
  }

  Future<void> _run(Future<String?> Function() action, String okText) async {
    if (_busy) return;
    setState(() => _busy = true);
    final err = await action();
    if (!mounted) return;
    setState(() => _busy = false);
    if (err != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err)));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(okText), duration: const Duration(milliseconds: 1200)));
      _refreshAll();
    }
  }

  void _openUser(int uid) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => UserProfileScreen(userId: uid)))
        .then((_) => _refreshAll());
  }

  void _openDm(User u) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => ChatScreen(peerId: u.id, peerName: u.label)));
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('我的好友'),
        bottom: TabBar(
          controller: _tab,
          tabs: [
            Tab(text: '好友 ${_friends.isEmpty ? '' : _friends.length}'),
            Tab(text: '收到 ${_incoming.isEmpty ? '' : _incoming.length}'),
            Tab(text: '发出 ${_outgoing.isEmpty ? '' : _outgoing.length}'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tab,
        children: [
          _friendsList(),
          _incomingList(),
          _outgoingList(),
        ],
      ),
    );
  }

  Widget _empty(String emoji, String text) => Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(emoji, style: const TextStyle(fontSize: 36)),
          const SizedBox(height: 8),
          Text(text, style: const TextStyle(color: Colors.grey, fontSize: 13)),
        ]),
      );

  // ---------------- 好友 ----------------
  Widget _friendsList() {
    if (_friends.isEmpty) return _empty('🫂', '还没有好友，去用户主页添加吧');
    return RefreshIndicator(
      onRefresh: _refreshAll,
      child: ListView.builder(
        itemCount: _friends.length,
        itemBuilder: (_, i) {
          final u = _friends[i];
          return ListTile(
            leading: MakaAvatar(user: u, size: 42),
            title: Text(u.label, maxLines: 1, overflow: TextOverflow.ellipsis),
            subtitle: u.customId != null ? Text('@${u.customId}', maxLines: 1) : null,
            onTap: () => _openUser(u.id),
            trailing: PopupMenuButton<String>(
              onSelected: (v) {
                if (v == 'dm') _openDm(u);
                if (v == 'del') _run(() => Api.removeFriend(u.id), '已删除好友');
              },
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'dm', child: Text('发私信')),
                PopupMenuItem(value: 'del', child: Text('删除好友')),
              ],
            ),
          );
        },
      ),
    );
  }

  // ---------------- 收到的申请 ----------------
  Widget _incomingList() {
    if (_incoming.isEmpty) return _empty('📭', '没有收到好友申请');
    return RefreshIndicator(
      onRefresh: _refreshAll,
      child: ListView.builder(
        itemCount: _incoming.length,
        itemBuilder: (_, i) {
          final r = _incoming[i];
          return ListTile(
            leading: MakaAvatar(user: r.user, size: 42),
            title: Text(r.user.label, maxLines: 1, overflow: TextOverflow.ellipsis),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (r.message.isNotEmpty) Text(r.message, maxLines: 2, overflow: TextOverflow.ellipsis),
                Text(formatTime(r.createdAt), style: const TextStyle(fontSize: 11)),
              ],
            ),
            isThreeLine: r.message.isNotEmpty,
            onTap: () => _openUser(r.user.id),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  tooltip: '同意',
                  icon: const Icon(Icons.check_circle, color: Colors.green),
                  onPressed: () => _run(() => Api.acceptFriend(r.id), '已同意申请'),
                ),
                IconButton(
                  tooltip: '拒绝',
                  icon: const Icon(Icons.cancel_outlined, color: Colors.grey),
                  onPressed: () => _run(() => Api.rejectFriend(r.id), '已拒绝申请'),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  // ---------------- 发出的申请 ----------------
  Widget _outgoingList() {
    if (_outgoing.isEmpty) return _empty('📤', '没有发出的好友申请');
    return RefreshIndicator(
      onRefresh: _refreshAll,
      child: ListView.builder(
        itemCount: _outgoing.length,
        itemBuilder: (_, i) {
          final r = _outgoing[i];
          return ListTile(
            leading: MakaAvatar(user: r.user, size: 42),
            title: Text(r.user.label, maxLines: 1, overflow: TextOverflow.ellipsis),
            subtitle: Text('等待验证 · ${formatTime(r.createdAt)}',
                maxLines: 1, style: const TextStyle(fontSize: 12)),
            onTap: () => _openUser(r.user.id),
            trailing: TextButton.icon(
              icon: const Icon(Icons.undo, size: 17),
              label: const Text('撤回'),
              onPressed: () => _run(() => Api.cancelFriend(r.id), '已撤回申请'),
            ),
          );
        },
      ),
    );
  }
}
