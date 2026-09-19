import 'package:flutter/material.dart';
import '../api.dart';
import 'chat_member_pick.dart';
import 'chat_group_screen.dart';

/// 发起新私信：搜索用户后进入会话；菜单可创建/加入聊天群组
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

  Future<void> _createGroup() async {
    final gid = await Navigator.push<int>(context, MaterialPageRoute(
      builder: (_) => const CreateChatGroupScreen(),
    ));
    if (!mounted || gid == null) return;
    if (!mounted) return;
    // 进入新群会话；NewChatScreen 与创建页一起弹出
    Navigator.pop(context);
    await Navigator.push(context, MaterialPageRoute(
      builder: (_) => ChatGroupScreen(groupId: gid, groupName: '群组$gid'),
    ));
  }

  Future<void> _joinByNumber() async {
    final ctrl = TextEditingController();
    final input = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('群号加入'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(hintText: '输入群号（纯数字）'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
            child: const Text('加入'),
          ),
        ],
      ),
    );
    if (input == null || input.isEmpty) return;
    final gid = int.tryParse(input);
    if (gid == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('群号格式不正确')));
      return;
    }
    final err = await Api.joinChatByNumber(gid);
    if (!mounted) return;
    if (err != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err)));
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('已加入群聊')));
    if (!mounted) return;
    Navigator.pop(context);
    await Navigator.push(context, MaterialPageRoute(
      builder: (_) => ChatGroupScreen(groupId: gid, groupName: '群组$gid'),
    ));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('发起私信'),
        actions: [
          PopupMenuButton<String>(
            tooltip: '群组',
            icon: const Icon(Icons.groups_outlined),
            onSelected: (v) {
              if (v == 'create') _createGroup();
              if (v == 'join') _joinByNumber();
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'create', child: ListTile(
                leading: Icon(Icons.group_add_outlined), title: Text('创建群组'), contentPadding: EdgeInsets.zero)),
              PopupMenuItem(value: 'join', child: ListTile(
                leading: Icon(Icons.pin_invoke_outlined), title: Text('群号加入'), contentPadding: EdgeInsets.zero)),
            ],
          ),
        ],
      ),
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
