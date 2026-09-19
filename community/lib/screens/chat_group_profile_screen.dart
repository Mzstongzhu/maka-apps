import 'package:flutter/material.dart';
import '../api.dart';
import 'chat_member_pick.dart';
import 'user_profile_screen.dart';

/// 群资料：成员列表 / 邀请 / 群号加入开关 / 踢人 / 退群（群主退群自动转让或解散）
class ChatGroupProfileScreen extends StatefulWidget {
  final int groupId;
  const ChatGroupProfileScreen({super.key, required this.groupId});
  @override
  State<ChatGroupProfileScreen> createState() => _ChatGroupProfileScreenState();
}

class _ChatGroupProfileScreenState extends State<ChatGroupProfileScreen> {
  ChatGroupDetail? _detail;
  bool _loading = true;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final d = await Api.getChatGroup(widget.groupId);
    if (!mounted) return;
    if (d == null) {
      Navigator.pop(context);
      return;
    }
    setState(() {
      _detail = d;
      _loading = false;
    });
  }

  Future<void> _invite() async {
    final existing = _detail!.members.map((m) => m.user.id).toSet();
    final picked = await Navigator.push<Set<int>>(context, MaterialPageRoute(
      builder: (_) => _InviteScreen(groupId: widget.groupId, excludeIds: existing),
    ));
    if (picked == null || picked.isEmpty || !mounted) return;
    setState(() => _busy = true);
    final (joined, err) = await Api.inviteToChat(widget.groupId, picked.toList());
    if (!mounted) return;
    setState(() => _busy = false);
    if (err != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err)));
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('已邀请 $joined 人入群')));
    _load();
  }

  Future<void> _editName() async {
    final ctrl = TextEditingController(text: _detail!.group.name);
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('修改群名'),
        content: TextField(
          controller: ctrl,
          maxLength: 20,
          autofocus: true,
          decoration: const InputDecoration(hintText: '1-20 个字符'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
            child: const Text('保存'),
          ),
        ],
      ),
    );
    if (name == null || name.isEmpty || name == _detail!.group.name) return;
    final err = await Api.updateChatGroup(widget.groupId, {'name': name});
    if (!mounted) return;
    if (err != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err)));
      return;
    }
    _load();
  }

  Future<void> _toggleJoinByNumber(bool v) async {
    final err = await Api.updateChatGroup(widget.groupId, {'join_by_number': v});
    if (!mounted) return;
    if (err != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err)));
      return;
    }
    setState(() => _detail!.group.joinByNumber = v);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(v ? '已开放群号加入，把群号 $widget.groupId 发给朋友即可' : '已关闭群号加入')),
    );
  }

  Future<void> _kick(ChatGroupMember m) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('移出群聊'),
        content: Text('确定将 ${m.user.label} 移出本群吗？'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('移出'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    final err = await Api.kickFromChat(widget.groupId, m.user.id);
    if (!mounted) return;
    if (err != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err)));
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('已移出')));
    _load();
  }

  Future<void> _leave() async {
    final isOwner = _detail!.iAmOwner;
    final alone = _detail!.members.length <= 1;
    final msg = isOwner
        ? (alone
            ? '你是群主且群内仅剩你一人，退出后群将被解散。'
            : '你是群主，退出后群主身份将自动转让给最早入群的成员。')
        : '退出后将不再接收该群消息。';
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(isOwner && alone ? '解散群聊' : '退出群聊'),
        content: Text('$msg\n确定退出「${_detail!.group.name}」吗？'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(isOwner && alone ? '解散并退出' : '退出'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    final (_, err) = await Api.leaveChat(widget.groupId);
    if (!mounted) return;
    if (err != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err)));
      return;
    }
    // 退出成功：关闭资料页和会话页
    Navigator.pop(context);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final d = _detail!;
    return Scaffold(
      appBar: AppBar(title: const Text('群资料')),
      body: ListView(
        children: [
          const SizedBox(height: 16),
          Center(
            child: CircleAvatar(
              radius: 40,
              backgroundColor: Theme.of(context).colorScheme.primaryContainer,
              child: Text(d.group.name.isNotEmpty ? d.group.name[0] : '?',
                  style: const TextStyle(fontSize: 30)),
            ),
          ),
          const SizedBox(height: 10),
          ListTile(
            title: Text(d.group.name, textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
            subtitle: Text('群号：${d.group.id}', textAlign: TextAlign.center),
            trailing: d.iAmOwner
                ? IconButton(icon: const Icon(Icons.edit_outlined), onPressed: _editName)
                : null,
          ),
          const Divider(),
          SwitchListTile(
            secondary: const Icon(Icons.pin_invoke_outlined),
            title: const Text('允许凭群号加入'),
            subtitle: Text(d.group.joinByNumber
                ? '他人输入群号 ${d.group.id} 即可加入'
                : '关闭后，仅能通过群成员邀请加入'),
            value: d.group.joinByNumber,
            onChanged: d.iAmOwner ? _toggleJoinByNumber : null,
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.person_add_alt),
            title: const Text('邀请成员'),
            trailing: _busy
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.chevron_right),
            onTap: _busy ? null : _invite,
          ),
          const Divider(),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
            child: Text('群成员（${d.members.length}）',
                style: const TextStyle(fontWeight: FontWeight.w600, color: Colors.grey, fontSize: 13)),
          ),
          ...d.members.map((m) {
            final url = absUrl(m.user.avatar);
            return ListTile(
              leading: CircleAvatar(
                backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                backgroundImage: url.isEmpty ? null : NetworkImage(url),
                child: url.isEmpty
                    ? Text(m.user.label.isNotEmpty ? m.user.label[0] : '?')
                    : null,
              ),
              title: Row(
                children: [
                  Flexible(child: Text(m.user.label, overflow: TextOverflow.ellipsis)),
                  if (m.isOwner)
                    Container(
                      margin: const EdgeInsets.only(left: 6),
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                      decoration: BoxDecoration(
                        color: Colors.amber.shade100,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Text('群主', style: TextStyle(fontSize: 10, color: Colors.brown)),
                    ),
                ],
              ),
              subtitle: Text(m.user.customId != null ? '@${m.user.customId}' : '#${m.user.id}',
                  style: const TextStyle(fontSize: 12)),
              trailing: (d.iAmOwner && !m.isOwner)
                  ? IconButton(
                      icon: const Icon(Icons.person_remove_outlined, color: Colors.redAccent),
                      onPressed: () => _kick(m),
                    )
                  : null,
              onTap: () => Navigator.push(context, MaterialPageRoute(
                  builder: (_) => UserProfileScreen(userId: m.user.id))),
            );
          }),
          const Divider(),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: FilledButton.icon(
              style: FilledButton.styleFrom(backgroundColor: Colors.redAccent),
              icon: const Icon(Icons.logout),
              label: Text(d.iAmOwner && d.members.length <= 1 ? '解散并退出群聊' : '退出群聊'),
              onPressed: _leave,
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

/// 邀请成员选择页
class _InviteScreen extends StatefulWidget {
  final int groupId;
  final Set<int> excludeIds;
  const _InviteScreen({required this.groupId, required this.excludeIds});
  @override
  State<_InviteScreen> createState() => _InviteScreenState();
}

class _InviteScreenState extends State<_InviteScreen> {
  final _selected = <int>{};

  void _confirm() {
    if (_selected.isEmpty) return;
    // 仅回传选择结果，实际邀请由群资料页统一调用并刷新
    Navigator.pop(context, _selected);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('选择要邀请的成员'),
        actions: [
          TextButton(
            onPressed: _selected.isEmpty ? null : _confirm,
            child: Text('邀请${_selected.isEmpty ? '' : '（${_selected.length}）'}',
                style: const TextStyle(color: Colors.white)),
          ),
        ],
      ),
      body: MemberPicker(
        selected: _selected,
        excludeIds: widget.excludeIds,
        onChanged: () => setState(() {}),
      ),
    );
  }
}
