import 'package:flutter/material.dart';
import '../api.dart';

/// 通用成员多选：好友列表 + 搜索（创建聊天群 / 邀请成员复用）
/// 选中的 id 保存在外部传入的 [selected] 中
class MemberPicker extends StatefulWidget {
  final Set<int> selected;
  final Set<int> excludeIds;
  final VoidCallback onChanged;
  const MemberPicker({
    super.key,
    required this.selected,
    this.excludeIds = const {},
    required this.onChanged,
  });

  @override
  State<MemberPicker> createState() => _MemberPickerState();
}

class _MemberPickerState extends State<MemberPicker> {
  final _searchCtrl = TextEditingController();
  List<User> _friends = [];
  List<User> _results = const [];
  bool _loading = true;
  bool _searching = false;

  @override
  void initState() {
    super.initState();
    _loadFriends();
  }

  Future<void> _loadFriends() async {
    final list = await Api.getFriends();
    if (!mounted) return;
    setState(() {
      _friends = list.where((u) => !widget.excludeIds.contains(u.id)).toList();
      _loading = false;
    });
  }

  Future<void> _doSearch() async {
    final q = _searchCtrl.text.trim();
    if (q.isEmpty) {
      setState(() => _searching = false);
      return;
    }
    final list = await Api.searchUsers(q);
    if (!mounted) return;
    setState(() {
      _results = list.where((u) => !widget.excludeIds.contains(u.id)).toList();
      _searching = true;
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Widget _tile(User u) {
    final checked = widget.selected.contains(u.id);
    final url = absUrl(u.avatar);
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: Theme.of(context).colorScheme.primaryContainer,
        backgroundImage: url.isEmpty ? null : NetworkImage(url),
        child: url.isEmpty ? Text(u.label.isNotEmpty ? u.label[0] : '?') : null,
      ),
      title: Text(u.label),
      subtitle: Text(u.customId != null ? '@${u.customId} · #${u.id}' : '#${u.id}',
          style: const TextStyle(fontSize: 12, color: Colors.grey)),
      trailing: Icon(checked ? Icons.check_circle : Icons.radio_button_unchecked,
          color: checked ? Theme.of(context).colorScheme.primary : Colors.grey),
      onTap: () {
        setState(() {
          if (checked) {
            widget.selected.remove(u.id);
          } else {
            widget.selected.add(u.id);
          }
        });
        widget.onChanged();
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final shown = _searching ? _results : _friends;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
          child: TextField(
            controller: _searchCtrl,
            textInputAction: TextInputAction.search,
            onSubmitted: (_) => _doSearch(),
            decoration: InputDecoration(
              hintText: '搜索昵称 / ID / 识别码',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: IconButton(
                icon: const Icon(Icons.clear),
                onPressed: () {
                  _searchCtrl.clear();
                  setState(() => _searching = false);
                },
              ),
              border: const OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(24))),
              contentPadding: const EdgeInsets.symmetric(vertical: 2),
            ),
          ),
        ),
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : shown.isEmpty
                  ? Center(
                      child: Text(_searching ? '没有找到对应用户' : '暂无好友，可先通过搜索添加用户',
                          style: const TextStyle(color: Colors.grey)),
                    )
                  : ListView.builder(
                      itemCount: shown.length,
                      itemBuilder: (ctx, i) => _tile(shown[i]),
                    ),
        ),
      ],
    );
  }
}

/// 创建聊天群：群名 + 成员多选
class CreateChatGroupScreen extends StatefulWidget {
  const CreateChatGroupScreen({super.key});
  @override
  State<CreateChatGroupScreen> createState() => _CreateChatGroupScreenState();
}

class _CreateChatGroupScreenState extends State<CreateChatGroupScreen> {
  final _nameCtrl = TextEditingController();
  final _selected = <int>{};
  bool _creating = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  Future<void> _create() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty || name.length > 20) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('群名需为 1-20 个字符')));
      return;
    }
    if (_selected.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('请至少选择 1 位成员')));
      return;
    }
    setState(() => _creating = true);
    final (id, err) = await Api.createChatGroup(name, _selected.toList());
    if (!mounted) return;
    if (err != null || id == null) {
      setState(() => _creating = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err ?? '创建失败')));
      return;
    }
    Navigator.pop(context, id);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('创建群组'),
        actions: [
          TextButton(
            onPressed: _creating ? null : _create,
            child: _creating
                ? const SizedBox(
                    width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                : Text('创建${_selected.isEmpty ? '' : '（${_selected.length}人）'}',
                    style: const TextStyle(color: Colors.white)),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
            child: TextField(
              controller: _nameCtrl,
              maxLength: 20,
              decoration: const InputDecoration(
                labelText: '群名称',
                hintText: '给群组起个名字',
                border: OutlineInputBorder(),
                counterText: '',
              ),
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: MemberPicker(
              selected: _selected,
              onChanged: () => setState(() {}),
            ),
          ),
        ],
      ),
    );
  }
}
