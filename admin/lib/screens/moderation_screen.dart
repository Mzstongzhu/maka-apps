import 'package:flutter/material.dart';
import '../admin_api.dart';

/// 内容审核：仅官方管理员。机器审核转人工的帖子/评论在此过审或驳回。
class ModerationScreen extends StatefulWidget {
  const ModerationScreen({super.key});
  @override
  State<ModerationScreen> createState() => _ModerationScreenState();
}

class _ModerationScreenState extends State<ModerationScreen> with AutomaticKeepAliveClientMixin {
  List<Map<String, dynamic>> _items = [];
  bool _loading = true;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final (items, err) = await AdminApi.getPending();
    if (!mounted) return;
    setState(() { _items = items; _loading = false; });
    if (err != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err)));
    }
  }

  Future<void> _moderate(Map<String, dynamic> item, bool approve) async {
    final kind = item['kind'] as String;
    final id = (item['id'] as num).toInt();
    final err = await AdminApi.moderate(kind, id, approve);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err ?? (approve ? '已通过' : '已驳回'))));
    _load();
  }

  String _authorName(Map<String, dynamic> item) {
    final a = item['author'] as Map<String, dynamic>?;
    return a?['display_name'] as String? ?? '用户${item['author_id'] ?? '?'}';
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_items.isEmpty) {
      return const Center(child: Text('没有待审核的内容 🎉', style: TextStyle(color: Colors.grey)));
    }
    return ListView.builder(
      itemCount: _items.length,
      itemBuilder: (ctx, i) {
        final item = _items[i];
        final isPost = item['kind'] == 'post';
        final content = item['content'] as String? ?? '';
        final excerpt = content.length > 160 ? '${content.substring(0, 160)}…' : content;
        final matched = ((item['matched_words'] as List?) ?? []).join('、');
        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Chip(label: Text(isPost ? '动态' : '评论', style: const TextStyle(fontSize: 11)), visualDensity: VisualDensity.compact),
                    const SizedBox(width: 8),
                    Expanded(child: Text(_authorName(item), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13))),
                  ],
                ),
                if (matched.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text('命中词：$matched', style: const TextStyle(fontSize: 12, color: Colors.orange)),
                  ),
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(excerpt, style: const TextStyle(fontSize: 13, height: 1.4)),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    OutlinedButton(
                      onPressed: () => _moderate(item, false),
                      style: OutlinedButton.styleFrom(foregroundColor: Colors.red, visualDensity: VisualDensity.compact),
                      child: const Text('驳回'),
                    ),
                    const SizedBox(width: 8),
                    FilledButton(
                      onPressed: () => _moderate(item, true),
                      style: FilledButton.styleFrom(visualDensity: VisualDensity.compact),
                      child: const Text('通过'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
