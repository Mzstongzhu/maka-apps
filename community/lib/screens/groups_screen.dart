import 'package:flutter/material.dart';
import '../api.dart';
import '../widgets/avatar.dart';
import 'group_detail_screen.dart';

class GroupsScreen extends StatefulWidget {
  const GroupsScreen({super.key});
  @override
  State<GroupsScreen> createState() => _GroupsScreenState();
}

class _GroupsScreenState extends State<GroupsScreen> {
  List<Group> _groups = [];
  List<Group> _mine = [];
  final _q = TextEditingController();
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final groups = await Api.getGroups(_q.text.trim());
    final mine = await Api.getMyGroups();
    if (!mounted) return;
    setState(() { _groups = groups; _mine = mine; _loading = false; });
  }

  Future<void> _create() async {
    final nameCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('创建群组'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: nameCtrl, maxLength: 30, decoration: const InputDecoration(labelText: '群组名称（1-30 字）')),
            const SizedBox(height: 8),
            TextField(controller: descCtrl, maxLines: 3, maxLength: 500, decoration: const InputDecoration(labelText: '群组简介（选填）')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('创建')),
        ],
      ),
    );
    if (ok != true) return;
    final name = nameCtrl.text.trim();
    if (name.isEmpty) return;
    String? err;
    await Api.createGroup(name, descCtrl.text.trim(), (id) async {
      if (!mounted || id == 0) return;
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => GroupDetailScreen(groupId: id)));
    }).then((e) => err = e);
    if (!mounted) return;
    if (err != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err!)));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('群组创建成功')));
      _load();
    }
  }

  @override
  void dispose() {
    _q.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('群组'),
        actions: [
          IconButton(icon: const Icon(Icons.add), tooltip: '创建群组', onPressed: _create),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                padding: const EdgeInsets.only(bottom: 24),
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
                    child: Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _q,
                            decoration: const InputDecoration(
                              hintText: '搜索群组…',
                              prefixIcon: Icon(Icons.search),
                              isDense: true,
                              border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(24))),
                            ),
                            onSubmitted: (_) => _load(),
                          ),
                        ),
                        const SizedBox(width: 8),
                        OutlinedButton(onPressed: _load, child: const Text('搜索')),
                      ],
                    ),
                  ),
                  if (_mine.isNotEmpty) ...[
                    const Padding(padding: EdgeInsets.fromLTRB(16, 10, 16, 4), child: Text('我的群组', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14))),
                    ..._mine.map((g) => ListTile(
                          leading: MakaAvatar(group: GroupBrief(id: g.id, name: g.name, avatar: g.avatar), size: 40),
                          title: Text(g.name),
                          trailing: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: g.myRole == 'owner' ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.1) : Colors.grey.shade200,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              g.myRole == 'owner' ? '群主' : g.myRole == 'admin' ? '管理' : '成员',
                              style: TextStyle(fontSize: 11, color: g.myRole == 'owner' ? Theme.of(context).colorScheme.primary : Colors.grey[600]),
                            ),
                          ),
                          onTap: () => _open(g.id),
                        )),
                  ],
                  const Padding(padding: EdgeInsets.fromLTRB(16, 10, 16, 4), child: Text('全部群组', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14))),
                  if (_groups.isEmpty)
                    Padding(padding: const EdgeInsets.symmetric(vertical: 40), child: Center(child: Text('没有找到群组', style: TextStyle(color: Colors.grey[500])))),
                  ..._groups.map((g) => Container(
                        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                        child: Card(
                          elevation: 0,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14), side: BorderSide(color: Colors.grey.shade200)),
                          child: ListTile(
                            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                            leading: MakaAvatar(group: GroupBrief(id: g.id, name: g.name, avatar: g.avatar), size: 46),
                            title: Text(g.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(g.description?.isNotEmpty == true ? g.description! : '暂无简介', maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                                Text('${g.memberCount} 位成员 · ${formatTime(g.createdAt)}创建', style: TextStyle(fontSize: 11, color: Colors.grey[500])),
                              ],
                            ),
                            trailing: g.joinApproval ? Text('需审核', style: TextStyle(fontSize: 11, color: Colors.grey[500])) : null,
                            onTap: () => _open(g.id),
                          ),
                        ),
                      )),
                ],
              ),
      ),
    );
  }

  Future<void> _open(int id) async {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => GroupDetailScreen(groupId: id)));
    _load();
  }
}
