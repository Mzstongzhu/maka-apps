import 'package:flutter/material.dart';
import '../api.dart';

/// 发起新私信：搜索用户后进入会话
class NewChatScreen extends StatefulWidget {
  final void Function(int peerId, String peerName) onPick;
  const NewChatScreen({super.key, required this.onPick});
  @override
  State<NewChatScreen> createState() => _NewChatScreenState();
}

class _NewChatScreenState extends State<NewChatScreen> {
  final _ctrl = TextEditingController();
  List<User> _results = [];
  bool _loading = false;
  bool _searched = false;

  Future<void> _search() async {
    final q = _ctrl.text.trim();
    if (q.isEmpty) return;
    setState(() { _loading = true; _searched = true; });
    final users = await Api.searchUsers(q);
    if (!mounted) return;
    setState(() { _results = users; _loading = false; });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('发起私信')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _ctrl,
                    autofocus: true,
                    textInputAction: TextInputAction.search,
                    onSubmitted: (_) => _search(),
                    decoration: const InputDecoration(
                      hintText: '输入昵称 / 自定义ID / 识别码',
                      prefixIcon: Icon(Icons.search),
                      border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(24))),
                      contentPadding: EdgeInsets.symmetric(vertical: 4),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton(onPressed: _loading ? null : _search, child: const Text('搜索')),
              ],
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : !_searched
                    ? const Center(child: Text('输入关键词查找用户', style: TextStyle(color: Colors.grey)))
                    : _results.isEmpty
                        ? const Center(child: Text('没有找到对应用户', style: TextStyle(color: Colors.grey)))
                        : ListView.builder(
                            itemCount: _results.length,
                            itemBuilder: (ctx, i) {
                              final u = _results[i];
                              return ListTile(
                                leading: CircleAvatar(
                                  backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                                  child: Text(u.label.isNotEmpty ? u.label[0] : '?'),
                                ),
                                title: Text(u.label),
                                subtitle: Text(u.customId != null ? '@${u.customId} · #${u.id}' : '#${u.id}',
                                    style: const TextStyle(fontSize: 12, color: Colors.grey)),
                                trailing: const Icon(Icons.chat_bubble_outline, size: 20),
                                onTap: () {
                                  Navigator.pop(context);
                                  widget.onPick(u.id, u.label);
                                },
                              );
                            },
                          ),
          ),
        ],
      ),
    );
  }
}
