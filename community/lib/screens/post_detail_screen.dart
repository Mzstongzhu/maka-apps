import 'package:flutter/material.dart';
import '../api.dart';
import '../widgets/avatar.dart';
import '../widgets/post_card.dart';
import '../widgets/user_tag.dart';
import 'user_profile_screen.dart';

class PostDetailScreen extends StatefulWidget {
  final int postId;
  const PostDetailScreen({super.key, required this.postId});
  @override
  State<PostDetailScreen> createState() => _PostDetailScreenState();
}

class _PostDetailScreenState extends State<PostDetailScreen> {
  Post? _post;
  List<Comment> _comments = [];
  bool _loading = true;
  final _input = TextEditingController();
  bool _sending = false;
  User? _me;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final post = await Api.getPost(widget.postId);
    final comments = await Api.getComments(widget.postId);
    final me = await Api.getMe();
    if (!mounted) return;
    setState(() { _post = post; _comments = comments; _loading = false; _me = me; });
  }

  Future<void> _send() async {
    final text = _input.text.trim();
    if (text.isEmpty || _sending || _post == null) return;
    setState(() => _sending = true);
    final (status, err) = await Api.addComment(widget.postId, text);
    if (!mounted) return;
    setState(() => _sending = false);
    if (err != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err)));
      return;
    }
    _input.clear();
    if (status == 'pending') {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('评论已提交机器审核，通过后公开显示')));
    } else {
      setState(() {
        _comments.add(Comment(id: DateTime.now().microsecondsSinceEpoch, author: _me, content: text, createdAt: DateTime.now().millisecondsSinceEpoch));
        _post!.commentCount++;
      });
    }
  }

  Future<void> _delComment(Comment c) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('删除评论'),
        content: const Text('删除这条评论？'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('删除')),
        ],
      ),
    );
    if (ok != true) return;
    final err = await Api.deleteComment(c.id);
    if (!mounted) return;
    if (err != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err)));
    } else {
      setState(() {
        _comments.removeWhere((x) => x.id == c.id);
        if (_post!.commentCount > 0) _post!.commentCount--;
      });
    }
  }

  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('动态详情')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _post == null
              ? const Center(child: Text('动态不存在或无权查看', style: TextStyle(color: Colors.grey)))
              : Column(
                  children: [
                    Expanded(
                      child: RefreshIndicator(
                        onRefresh: _load,
                        child: ListView(
                          padding: const EdgeInsets.only(bottom: 16),
                          children: [
                            PostCard(
                              post: _post!,
                              myId: _me?.id ?? 0,
                              myIsAdmin: _me?.role == 'admin',
                              onChanged: _load,
                            ),
                            Container(
                              margin: const EdgeInsets.fromLTRB(12, 6, 12, 0),
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: Theme.of(context).cardColor,
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(color: Colors.grey.shade200),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('评论（${_comments.length}）', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                                  const SizedBox(height: 4),
                                  ..._comments.map((c) {
                                    final mine = c.author?.id == _me?.id;
                                    return Row(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        GestureDetector(
                                          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => UserProfileScreen(userId: c.author!.id))),
                                          child: MakaAvatar(user: c.author, size: 32),
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Padding(
                                            padding: const EdgeInsets.symmetric(vertical: 4),
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Row(
                                                  children: [
                                                    Flexible(child: UserTag(user: c.author, sub: formatTime(c.createdAt))),
                                                    const Spacer(),
                                                    if (mine || _me?.role == 'admin')
                                                      GestureDetector(
                                                        onTap: () => _delComment(c),
                                                        child: Text('删除', style: TextStyle(fontSize: 12, color: Colors.grey[500])),
                                                      ),
                                                  ],
                                                ),
                                                const SizedBox(height: 2),
                                                Text(c.content, style: const TextStyle(fontSize: 14, height: 1.4)),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ],
                                    );
                                  }),
                                  if (_comments.isEmpty)
                                    Padding(
                                      padding: const EdgeInsets.symmetric(vertical: 20),
                                      child: Center(child: Text('还没有评论，来抢沙发～', style: TextStyle(color: Colors.grey[500], fontSize: 13))),
                                    ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    // 评论输入
                    SafeArea(
                      top: false,
                      child: Container(
                        padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
                        decoration: BoxDecoration(
                          color: Theme.of(context).cardColor,
                          border: Border(top: BorderSide(color: Colors.grey.shade200)),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _input,
                                minLines: 1,
                                maxLines: 4,
                                maxLength: 2000,
                                decoration: const InputDecoration(
                                  hintText: '友善评论，共建良好社区…',
                                  isDense: true,
                                  border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(22))),
                                  contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                                  counterText: '',
                                ),
                                onSubmitted: (_) => _send(),
                              ),
                            ),
                            const SizedBox(width: 8),
                            IconButton.filled(
                              onPressed: _sending ? null : _send,
                              icon: _sending
                                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                  : const Icon(Icons.send, size: 18),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
    );
  }
}
