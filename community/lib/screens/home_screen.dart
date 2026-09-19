import 'package:flutter/material.dart';
import '../api.dart';
import '../widgets/avatar.dart';
import '../widgets/post_card.dart';
import 'composer_screen.dart';
import 'post_detail_screen.dart';
import 'search_screen.dart';
import 'scanner_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => HomeScreenState();
}

class HomeScreenState extends State<HomeScreen> with AutomaticKeepAliveClientMixin {
  List<Post> _posts = [];
  bool _hasMore = false;
  bool _loading = true;
  User? _me;
  bool _checkedToday = false;
  bool _checkinBusy = false;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    refresh();
  }

  Future<void> refresh() async {
    final (posts, hasMore) = await Api.getFeed();
    final me = await Api.getMe();
    if (me != null) {
      try {
        _checkedToday = await Api.checkinStatus();
      } catch (_) {}
    }
    if (!mounted) return;
    setState(() {
      _posts = posts;
      _hasMore = hasMore;
      _loading = false;
      _me = me;
    });
  }

  Future<void> _loadMore() async {
    if (_posts.isEmpty || _loading) return;
    setState(() => _loading = true);
    final (posts, hasMore) = await Api.getFeed(before: _posts.last.id);
    if (!mounted) return;
    setState(() {
      _posts.addAll(posts);
      _hasMore = hasMore;
      _loading = false;
    });
  }

  Future<void> _checkin() async {
    setState(() => _checkinBusy = true);
    final (points, streak, err) = await Api.checkin();
    if (!mounted) return;
    setState(() {
      _checkinBusy = false;
      if (err == null) _checkedToday = true;
    });
    if (err != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err)));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('签到成功！获得 $points 积分，已连签 $streak 天')));
      refresh();
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('玛卡之声社区'),
        actions: [
          IconButton(icon: const Icon(Icons.qr_code_scanner), tooltip: '扫一扫', onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ScannerScreen()))),
          IconButton(icon: const Icon(Icons.search), tooltip: '搜索', onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SearchScreen()))),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: refresh,
        child: _loading && _posts.isEmpty
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                padding: const EdgeInsets.only(bottom: 24),
                children: [
                  // 签到卡
                  if (_me != null)
                    Container(
                      margin: const EdgeInsets.fromLTRB(12, 10, 12, 6),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(color: cs.primary.withValues(alpha: 0.06), borderRadius: BorderRadius.circular(14)),
                      child: Row(
                        children: [
                          GestureDetector(
                            onTap: () {},
                            child: MakaAvatar(user: _me, size: 40),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(_me!.label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                                Text('#${_me!.id} · ⭐ ${_me!.points} 积分', style: TextStyle(fontSize: 11, color: Colors.grey[600])),
                              ],
                            ),
                          ),
                          FilledButton.tonal(
                            onPressed: _checkedToday || _checkinBusy ? null : _checkin,
                            style: FilledButton.styleFrom(visualDensity: VisualDensity.compact),
                            child: Text(_checkedToday ? '今日已签到' : '签到 +5'),
                          ),
                        ],
                      ),
                    ),
                  // 发动态入口
                  GestureDetector(
                    onTap: () async {
                      final posted = await Navigator.push<bool>(context, MaterialPageRoute(builder: (_) => const ComposerScreen()));
                      if (posted == true) refresh();
                    },
                    child: Container(
                      margin: const EdgeInsets.fromLTRB(12, 6, 12, 6),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                      decoration: BoxDecoration(
                        color: Theme.of(context).cardColor,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.edit_note, color: cs.primary),
                          const SizedBox(width: 8),
                          Text('分享此刻的想法…', style: TextStyle(color: Colors.grey[500], fontSize: 14)),
                        ],
                      ),
                    ),
                  ),
                  // 动态流
                  if (_posts.isEmpty && !_loading)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 60),
                      child: Column(
                        children: [
                          const Text('🌱', style: TextStyle(fontSize: 40)),
                          const SizedBox(height: 8),
                          Text('这里还很安静，发布第一条动态吧', style: TextStyle(color: Colors.grey[500])),
                        ],
                      ),
                    ),
                  ..._posts.map((p) => PostCard(
                        post: p,
                        myId: _me?.id ?? 0,
                        myIsAdmin: _me?.role == 'admin',
                        onOpenComments: () async {
                          await Navigator.push(context, MaterialPageRoute(builder: (_) => PostDetailScreen(postId: p.id)));
                          refresh();
                        },
                        onRemoved: refresh,
                        onChanged: refresh,
                      )),
                  if (_hasMore && _posts.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: OutlinedButton(onPressed: _loading ? null : _loadMore, child: const Text('加载更多')),
                    ),
                  if (_loading && _posts.isNotEmpty)
                    const Padding(padding: EdgeInsets.all(12), child: Center(child: CircularProgressIndicator())),
                ],
              ),
      ),
    );
  }
}
