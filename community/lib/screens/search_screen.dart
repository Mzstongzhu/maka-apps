import 'package:flutter/material.dart';
import '../api.dart';
import '../widgets/avatar.dart';
import '../widgets/user_tag.dart';
import '../widgets/post_card.dart';
import 'user_profile_screen.dart';
import 'post_detail_screen.dart';
import 'group_detail_screen.dart';
import 'announcements_screen.dart';
import 'activity_detail_screen.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});
  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _ctrl = TextEditingController();
  final _focus = FocusNode();
  SearchResult? _result;
  bool _loading = false;
  bool _searched = false;
  int _myId = 0;

  @override
  void initState() {
    super.initState();
    _focus.requestFocus();
    Api.getMe().then((u) {
      if (mounted) setState(() => _myId = u?.id ?? 0);
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _focus.dispose();
    super.dispose();
  }

  Future<void> _doSearch([String? q]) async {
    final query = (q ?? _ctrl.text).trim();
    if (query.isEmpty) return;
    _focus.unfocus();
    setState(() {
      _loading = true;
      _searched = true;
      _ctrl.text = query;
    });
    final r = await Api.searchAll(query);
    if (!mounted) return;
    setState(() {
      _result = r;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: Padding(
          padding: const EdgeInsets.only(right: 12),
          child: TextField(
            controller: _ctrl,
            focusNode: _focus,
            textInputAction: TextInputAction.search,
            onSubmitted: _doSearch,
            decoration: InputDecoration(
              hintText: '搜索动态、用户、群组…',
              isDense: true,
              filled: true,
              fillColor: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            ),
          ),
        ),
        actions: [
          IconButton(onPressed: () => _doSearch(), icon: const Icon(Icons.search)),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (!_searched) {
      return const Center(
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(Icons.search, size: 56, color: Colors.grey),
          SizedBox(height: 12),
          Text('搜索社区内容', style: TextStyle(color: Colors.grey)),
        ]),
      );
    }
    final r = _result;
    if (r == null || r.total == 0) {
      return const Center(child: Text('没有找到相关内容', style: TextStyle(color: Colors.grey)));
    }
    return ListView(
      padding: const EdgeInsets.only(bottom: 24),
      children: [
        if (r.users.isNotEmpty) ...[
          _header('用户', r.users.length),
          ...r.users.map((u) => Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: UserRow(
                  user: u,
                  sub: u.bio,
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => UserProfileScreen(userId: u.id))),
                ),
              )),
        ],
        if (r.posts.isNotEmpty) ...[
          _header('动态', r.posts.length),
          ...r.posts.map((p) => PostCard(
                post: p,
                myId: _myId,
                onOpenComments: () => Navigator.push(context, MaterialPageRoute(builder: (_) => PostDetailScreen(postId: p.id))),
              )),
        ],
        if (r.groups.isNotEmpty) ...[
          _header('群组', r.groups.length),
          ...r.groups.map((g) => ListTile(
                leading: MakaAvatar(group: GroupBrief(id: g.id, name: g.name, avatar: g.avatar), size: 40),
                title: Text(g.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                subtitle: Text('${g.memberCount} 位成员 · ${g.description ?? ''}', maxLines: 1, overflow: TextOverflow.ellipsis),
                trailing: g.isMember ? const Text('已加入', style: TextStyle(fontSize: 12, color: Colors.grey)) : null,
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => GroupDetailScreen(groupId: g.id))),
              )),
        ],
        if (r.announcements.isNotEmpty) ...[
          _header('公告', r.announcements.length),
          ...r.announcements.map((a) => ListTile(
                leading: const Icon(Icons.campaign_outlined),
                title: Text(a.title, maxLines: 1, overflow: TextOverflow.ellipsis),
                subtitle: Text(formatTime(a.createdAt), style: const TextStyle(fontSize: 11)),
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AnnouncementsScreen())),
              )),
        ],
        if (r.activities.isNotEmpty) ...[
          _header('活动', r.activities.length),
          ...r.activities.map((a) => ListTile(
                leading: const Icon(Icons.emoji_events_outlined),
                title: Text(a.title, maxLines: 1, overflow: TextOverflow.ellipsis),
                subtitle: Text(a.startTime, style: const TextStyle(fontSize: 11)),
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ActivityDetailScreen(activityId: a.id))),
              )),
        ],
      ],
    );
  }

  Widget _header(String title, int count) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
      child: Text('$title · $count', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.grey[700])),
    );
  }
}
