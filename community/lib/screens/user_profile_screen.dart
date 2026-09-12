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

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    final me = await Api.getMe();
    final (u, posts) = await Api.getUserProfile(widget.userId);
    if (!mounted) return;
    setState(() {
      _myId = me?.id ?? 0;
      _myIsAdmin = me?.role == 'admin';
      _user = u;
      _posts = posts;
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
                            SizedBox(
                              width: double.infinity,
                              height: 40,
                              child: isMe
                                  ? OutlinedButton.icon(
                                      onPressed: () => Navigator.pop(context),
                                      icon: const Icon(Icons.edit_note, size: 18),
                                      label: const Text('编辑资料请前往「设置」'),
                                    )
                                  : FilledButton.icon(
                                      onPressed: _openDm,
                                      icon: const Icon(Icons.chat_bubble_outline, size: 18),
                                      label: const Text('发私信'),
                                    ),
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
