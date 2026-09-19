import 'package:flutter/material.dart';
import '../api.dart';
import '../widgets/avatar.dart';
import '../widgets/user_tag.dart';
import '../widgets/post_card.dart';
import 'chat.dart';
import 'post_detail_screen.dart';

class UserProfileScreen extends StatefulWidget {
  final int userId;
  const UserProfileScreen({super.key, required this.userId});
  @override
  State<UserProfileScreen> createState() => _UserProfileScreenState();
}

class _UserProfileScreenState extends State<UserProfileScreen> {
  User? _user;
  List<Post> _posts = [];
  bool _loading = true;
  String? _error;
  int _myId = 0;
  bool _myIsAdmin = false;
  String _rel = 'none'; // none / pending_out / pending_in / friends
  bool _friendBusy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    final me = await Api.getMe();
    final (u, posts) = await Api.getUserProfile(widget.userId);
    final rel = me == null || me.id == widget.userId ? 'none' : await Api.friendStatus(widget.userId);
    if (!mounted) return;
    setState(() {
      _myId = me?.id ?? 0;
      _myIsAdmin = me?.role == 'admin';
      _user = u;
      _posts = posts;
      _rel = rel;
      _loading = false;
      _error = u == null ? '用户不存在或已注销' : null;
    });
  }

  bool get isMe => _user?.id == _myId;

  void _openDm() {
    final u = _user;
    if (u == null) return;
    Navigator.push(context, MaterialPageRoute(builder: (_) => ChatScreen(peerId: u.id, peerName: u.label)));
  }

  // ---------------- 好友操作 ----------------
  Future<void> _addFriend() async {
    final msgCtrl = TextEditingController();
    final send = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('添加 ${_user?.label ?? ''} 为好友'),
        content: TextField(
          controller: msgCtrl,
          maxLength: 50,
          maxLines: 2,
          decoration: const InputDecoration(hintText: '验证信息（选填）', border: OutlineInputBorder()),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('发送申请')),
        ],
      ),
    );
    if (send != true) return;
    setState(() => _friendBusy = true);
    final (status, _, err) = await Api.sendFriendRequest(widget.userId, message: msgCtrl.text.trim());
    if (!mounted) return;
    setState(() => _friendBusy = false);
    if (err != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err)));
      return;
    }
    setState(() => _rel = status == 'friends' ? 'friends' : 'pending_out');
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(status == 'friends' ? '你们已成为好友' : '好友申请已发送'),
      duration: const Duration(milliseconds: 1500),
    ));
  }

  Future<void> _cancelRequest() async {
    // 从发出列表找到对应该用户的申请
    final list = await Api.getOutgoingFriends();
    final req = list.where((r) => r.user.id == widget.userId).toList();
    if (req.isEmpty) {
      _load();
      return;
    }
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('撤回好友申请'),
        content: const Text('确定撤回对该用户的好友申请吗？'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('撤回')),
        ],
      ),
    );
    if (ok != true) return;
    final err = await Api.cancelFriend(req.first.id);
    if (!mounted) return;
    if (err != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err)));
    } else {
      setState(() => _rel = 'none');
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('已撤回申请'), duration: Duration(milliseconds: 1200)));
    }
  }

  Future<void> _acceptIncoming() async {
    final list = await Api.getIncomingFriends();
    final req = list.where((r) => r.user.id == widget.userId).toList();
    if (req.isEmpty) {
      _load();
      return;
    }
    final err = await Api.acceptFriend(req.first.id);
    if (!mounted) return;
    if (err != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err)));
    } else {
      setState(() => _rel = 'friends');
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('已同意，你们成为好友'), duration: Duration(milliseconds: 1200)));
    }
  }

  Future<void> _removeFriend() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('删除好友'),
        content: Text('确定删除 ${_user?.label ?? ''} 吗？删除后对方不会收到通知。'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    final err = await Api.removeFriend(widget.userId);
    if (!mounted) return;
    if (err != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err)));
    } else {
      setState(() => _rel = 'none');
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('已删除好友'), duration: Duration(milliseconds: 1200)));
    }
  }

  Widget _friendButton() {
    if (isMe) {
      return OutlinedButton.icon(
        onPressed: () => Navigator.pop(context),
        icon: const Icon(Icons.edit_note, size: 18),
        label: const Text('编辑资料请前往「设置」'),
      );
    }
    switch (_rel) {
      case 'friends':
        return OutlinedButton.icon(
          onPressed: _friendBusy ? null : _removeFriend,
          icon: const Icon(Icons.person_remove_outlined, size: 18),
          style: OutlinedButton.styleFrom(foregroundColor: Colors.red),
          label: const Text('已是好友 · 删除'),
        );
      case 'pending_out':
        return OutlinedButton.icon(
          onPressed: _friendBusy ? null : _cancelRequest,
          icon: const Icon(Icons.hourglass_top, size: 18),
          label: const Text('已申请 · 撤回'),
        );
      case 'pending_in':
        return FilledButton.icon(
          onPressed: _friendBusy ? null : _acceptIncoming,
          icon: const Icon(Icons.person_add_alt_1, size: 18),
          label: const Text('对方申请中 · 同意'),
        );
      default:
        return FilledButton.icon(
          onPressed: _friendBusy ? null : _addFriend,
          icon: _friendBusy
              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : const Icon(Icons.person_add_alt, size: 18),
          label: const Text('加好友'),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: Text(_user?.label ?? '用户主页')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!, style: const TextStyle(color: Colors.grey)))
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(
                    padding: const EdgeInsets.only(bottom: 24),
                    children: [
                      // 头部资料卡
                      Container(
                        margin: const EdgeInsets.all(12),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Theme.of(context).cardColor,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.grey.shade200),
                        ),
                        child: Column(
                          children: [
                            Row(
                              children: [
                                MakaAvatar(user: _user, size: 64),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      UserTag(user: _user),
                                      const SizedBox(height: 4),
                                      if (_user?.customId != null)
                                        Text('@${_user!.customId}', style: TextStyle(fontSize: 13, color: Colors.grey[600])),
                                      Text('#${_user!.id} · ⭐ ${_user!.points} 积分', style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            if (_user?.bio != null && _user!.bio!.isNotEmpty) ...[
                              const SizedBox(height: 12),
                              Align(
                                alignment: Alignment.centerLeft,
                                child: Text(_user!.bio!, style: const TextStyle(fontSize: 14)),
                              ),
                            ],
                            if (_user!.createdAt > 0) ...[
                              const SizedBox(height: 8),
                              Align(
                                alignment: Alignment.centerLeft,
                                child: Text('加入于 ${formatTime(_user!.createdAt)}', style: TextStyle(fontSize: 12, color: Colors.grey[500])),
                              ),
                            ],
                            const SizedBox(height: 14),
                            Row(
                              children: [
                                Expanded(child: _friendButton()),
                                if (!isMe) ...[
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: OutlinedButton.icon(
                                      onPressed: _openDm,
                                      icon: const Icon(Icons.chat_bubble_outline, size: 18),
                                      label: const Text('发私信'),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ],
                        ),
                      ),
                      // 动态
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 4, 16, 6),
                        child: Text('TA 的动态 · ${_posts.length}', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: cs.primary)),
                      ),
                      if (_posts.isEmpty)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 40),
                          child: Center(child: Text('暂无动态', style: TextStyle(color: Colors.grey))),
                        ),
                      ..._posts.map((p) => PostCard(
                            post: p,
                            myId: _myId,
                            myIsAdmin: _myIsAdmin,
                            onOpenComments: () => Navigator.push(context, MaterialPageRoute(builder: (_) => PostDetailScreen(postId: p.id))),
                            onRemoved: _load,
                          )),
                    ],
                  ),
                ),
    );
  }
}
