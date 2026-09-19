import 'package:flutter/material.dart';
import '../api.dart';
import '../widgets/post_card.dart';
import 'post_detail_screen.dart';
import 'composer_screen.dart';

/// 标签详情：标签头（名称/动态数）+ 最新 / 热门 动态流
class TagScreen extends StatefulWidget {
  final String name;
  const TagScreen({super.key, required this.name});
  @override
  State<TagScreen> createState() => _TagScreenState();
}

class _TagScreenState extends State<TagScreen> {
  TagInfo? _tag;
  final List<Post> _posts = [];
  String _sort = 'new';
  bool _loading = true;
  bool _hasMore = false;
  User? _me;

  @override
  void initState() {
    super.initState();
    _load(reset: true);
  }

  Future<void> _load({bool reset = false}) async {
    if (reset) {
      setState(() { _loading = true; _posts.clear(); });
    }
    final before = (_sort == 'new' && _posts.isNotEmpty) ? _posts.last.id : 0;
    final (tag, items, hasMore) = await Api.getTagDetail(widget.name, sort: _sort, before: before);
    _me ??= await Api.getMe();
    if (!mounted) return;
    setState(() {
      _tag = tag;
      if (!reset) _posts.addAll(items); else _posts
        ..clear()
        ..addAll(items);
      _hasMore = hasMore;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: Text('#${widget.name}')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          // 进入发布器并预填标签，发布后刷新标签流
          final posted = await Navigator.push<bool>(context,
              MaterialPageRoute(builder: (_) => ComposerScreen(prefillTag: widget.name)));
          if (posted == true) _load(reset: true);
        },
        icon: const Icon(Icons.edit),
        label: const Text('带标签发布'),
      ),
      body: _loading && _posts.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : _tag == null
              ? Center(child: Text('标签 #${widget.name}# 不存在', style: TextStyle(color: Colors.grey[600])))
              : RefreshIndicator(
                  onRefresh: () => _load(reset: true),
                  child: ListView(
                    padding: const EdgeInsets.only(bottom: 88),
                    children: [
                      // 标签头
                      Container(
                        margin: const EdgeInsets.fromLTRB(12, 12, 12, 6),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(colors: [cs.primary, cs.primary.withValues(alpha: 0.75)]),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(children: [
                              const Icon(Icons.tag, color: Colors.white),
                              Expanded(
                                child: Text(_tag!.name,
                                    style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
                              ),
                            ]),
                            const SizedBox(height: 4),
                            Text('${_tag!.postCount} 篇动态 · 标签内容按兴趣聚合',
                                style: const TextStyle(color: Colors.white70, fontSize: 12)),
                          ],
                        ),
                      ),
                      // 最新 / 热门
                      Padding(
                        padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
                        child: SegmentedButton<String>(
                          segments: const [
                            ButtonSegment(value: 'new', icon: Icon(Icons.new_releases_outlined), label: Text('最新')),
                            ButtonSegment(value: 'hot', icon: Icon(Icons.local_fire_department_outlined), label: Text('热门')),
                          ],
                          selected: {_sort},
                          onSelectionChanged: (s) {
                            setState(() => _sort = s.first);
                            _load(reset: true);
                          },
                        ),
                      ),
                      if (_posts.isEmpty && !_loading)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 60),
                          child: Center(child: Text('还没有人带 #${widget.name}# 发布', style: TextStyle(color: Colors.grey[500]))),
                        ),
                      ..._posts.map((p) => PostCard(
                            post: p,
                            myId: _me?.id ?? 0,
                            myIsAdmin: _me?.role == 'admin',
                            onOpenComments: () async {
                              await Navigator.push(context, MaterialPageRoute(builder: (_) => PostDetailScreen(postId: p.id)));
                              _load(reset: true);
                            },
                            onRemoved: () => _load(reset: true),
                            onChanged: () => _load(reset: true),
                          )),
                      if (_hasMore && _posts.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: OutlinedButton(onPressed: _loading ? null : () => _load(), child: const Text('加载更多')),
                        ),
                      if (_loading && _posts.isNotEmpty)
                        const Padding(padding: EdgeInsets.all(12), child: Center(child: CircularProgressIndicator())),
                    ],
                  ),
                ),
    );
  }
}
