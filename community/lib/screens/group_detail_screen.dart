import 'dart:async';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../api.dart';
import '../widgets/avatar.dart';
import '../widgets/user_tag.dart';
import '../widgets/post_card.dart';
import '../widgets/chat_media.dart';
import '../widgets/chat_input.dart';
import '../widgets/message_actions.dart';
import 'composer_screen.dart';
import 'post_detail_screen.dart';
import 'user_profile_screen.dart';

class GroupDetailScreen extends StatefulWidget {
  final int groupId;
  const GroupDetailScreen({super.key, required this.groupId});
  @override
  State<GroupDetailScreen> createState() => _GroupDetailScreenState();
}

class _GroupDetailScreenState extends State<GroupDetailScreen> {
  Group? _group;
  List<User> _members = [];
  List<User> _requests = [];
  int _pendingCount = 0;
  List<Post> _posts = [];
  List<GroupMessage> _chat = [];
  final _chatScroll = ScrollController();
  int _tab = 0;
  bool _loading = true;
  User? _me;
  StreamSubscription? _msgSub;

  bool get isMember => _group?.isMember ?? false;
  bool get canManage => _group?.canManage ?? false || _me?.role == 'admin';
  bool get isOwner => _group?.myRole == 'owner';

  @override
  void initState() {
    super.initState();
    _loadAll();
    _msgSub = SocketService.groupMsgStream.listen((m) {
      final msg = GroupMessage.fromJson(m);
      if (!mounted) return;
      setState(() {
        // 替换自己的本地乐观消息
        if (msg.fromId == (_me?.id ?? 0)) {
          _chat.removeWhere((e) => e.id < 0 && e.content == msg.content && e.type == msg.type);
        }
        if (msg.id > 0 && _chat.any((e) => e.id == msg.id)) return;
        _chat.add(msg);
      });
      _scrollChatBottom();
    });
  }

  Future<void> _loadAll() async {
    final me = await Api.getMe();
    final (group, members, pending, err) = await Api.getGroupDetail(widget.groupId);
    if (!mounted) return;
    if (err != null || group == null) {
      setState(() { _loading = false; });
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err ?? '小社区不存在')));
      return;
    }
    setState(() { _group = group; _members = members; _pendingCount = pending; _me = me; _loading = false; });
    SocketService.enterGroup(widget.groupId);
    _loadFeed();
    _loadChat();
    if (canManage) _loadRequests();
  }

  Future<void> _loadFeed() async {
    final (posts, _) = await Api.getFeed(groupId: widget.groupId);
    if (!mounted) return;
    setState(() => _posts = posts);
  }

  Future<void> _loadChat() async {
    final chat = await Api.getGroupChat(widget.groupId);
    if (!mounted) return;
    setState(() => _chat = chat);
    _scrollChatBottom();
  }

  Future<void> _loadRequests() async {
    _requests = await Api.getGroupRequests(widget.groupId);
    if (!mounted) return;
    setState(() {});
  }

  void _scrollChatBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_chatScroll.hasClients) _chatScroll.jumpTo(_chatScroll.position.maxScrollExtent);
    });
  }

  Future<void> _join() async {
    final (pending, err) = await Api.joinGroup(widget.groupId);
    if (!mounted) return;
    if (err != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err)));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(pending ? '已提交申请，等待管理员审核' : '加入成功')));
      _loadAll();
    }
  }

  Future<void> _leave() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('退出小社区'),
        content: const Text('确定退出该小社区？'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('退出')),
        ],
      ),
    );
    if (ok != true) return;
    final err = await Api.leaveGroup(widget.groupId);
    if (!mounted) return;
    if (err != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err)));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('已退出')));
      Navigator.pop(context);
    }
  }

  /// ChatInputBar 回调（文本/图/语音/视频）：乐观插入 + 发送
  Future<String?> _onChatSend(String type, String content, int duration) async {
    final temp = GroupMessage(
      id: -DateTime.now().millisecondsSinceEpoch,
      fromId: _me?.id ?? 0,
      content: content,
      type: type,
      duration: duration,
      createdAt: DateTime.now().millisecondsSinceEpoch,
      author: _me,
    );
    setState(() => _chat.add(temp));
    _scrollChatBottom();
    final err = await Api.sendGroupChat(widget.groupId, content, type: type, duration: duration);
    if (err != null && mounted) {
      setState(() => _chat.removeWhere((m) => m.id == temp.id));
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err)));
      return err;
    }
    return null;
  }

  // ---------- 管理 ----------

  Future<void> _saveSettings() async {
    final g = _group!;
    final nameCtrl = TextEditingController(text: g.name);
    final descCtrl = TextEditingController(text: g.description ?? '');
    var approval = g.joinApproval;
    var public = g.postsPublic;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setD) => AlertDialog(
          title: const Text('小社区设置'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: nameCtrl, maxLength: 30, decoration: const InputDecoration(labelText: '小社区名称')),
              TextField(controller: descCtrl, maxLines: 3, maxLength: 500, decoration: const InputDecoration(labelText: '小社区简介')),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('加入审核', style: TextStyle(fontSize: 14)),
                subtitle: const Text('新成员需管理员审核', style: TextStyle(fontSize: 12)),
                value: approval,
                onChanged: (v) => setD(() => approval = v),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('动态公开到社区', style: TextStyle(fontSize: 14)),
                subtitle: const Text('群内动态出现在公开动态流', style: TextStyle(fontSize: 12)),
                value: public,
                onChanged: (v) => setD(() => public = v),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('保存')),
          ],
        ),
      ),
    );
    if (ok != true) return;
    final err = await Api.saveGroupSettings(widget.groupId, {
      'name': nameCtrl.text.trim(),
      'description': descCtrl.text.trim(),
      'join_approval': approval,
      'posts_public': public,
    });
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err ?? '设置已保存')));
    if (err == null) _loadAll();
  }

  Future<void> _changeAvatar() async {
    XFile? pic;
    try {
      final picker = ImagePicker();
      pic = await picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('打开相册失败: $e')));
      return;
    }
    if (pic == null) return;
    final (url, upErr) = await Api.uploadImage(pic.path, mime: pic.mimeType);
    if (url == null) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('上传失败：${upErr ?? "未知错误"}')));
      return;
    }
    final err = await Api.saveGroupSettings(widget.groupId, {'avatar': url});
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err ?? '群头像已更新')));
    if (err == null) _loadAll();
  }

  Future<void> _kick(User u) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('移出成员'),
        content: Text('确定将 ${u.label} 移出小社区？'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('移出')),
        ],
      ),
    );
    if (ok != true) return;
    final err = await Api.kickMember(widget.groupId, u.id);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err ?? '已移出')));
    if (err == null) _loadAll();
  }

  Future<void> _setAdmin(User u, bool make) async {
    final err = await Api.setGroupAdmin(widget.groupId, u.id, make);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err ?? (make ? '已任命为管理员' : '已撤销管理员'))));
    if (err == null) _loadAll();
  }

  Future<void> _invite() async {
    final qCtrl = TextEditingController();
    List<User> results = [];
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) => Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('拉人进群', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: qCtrl,
                      decoration: const InputDecoration(hintText: '识别码 / 自定义ID / 昵称', isDense: true, border: OutlineInputBorder()),
                      onSubmitted: (_) async {
                        final users = await Api.searchUsers(qCtrl.text.trim());
                        setSheet(() => results = users.where((u) => !_members.any((m) => m.id == u.id)).toList());
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  FilledButton.tonal(
                    onPressed: () async {
                      final users = await Api.searchUsers(qCtrl.text.trim());
                      setSheet(() => results = users.where((u) => !_members.any((m) => m.id == u.id)).toList());
                    },
                    child: const Text('搜索'),
                  ),
                ],
              ),
              ...results.map((u) => ListTile(
                    leading: MakaAvatar(user: u, size: 36),
                    title: Text(u.label, style: const TextStyle(fontSize: 14)),
                    subtitle: Text('#${u.id}', style: const TextStyle(fontSize: 11)),
                    trailing: FilledButton.tonal(
                      onPressed: () async {
                        final err = await Api.inviteMember(widget.groupId, u.id);
                        if (!ctx.mounted) return;
                        if (err != null) {
                          ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text(err)));
                        } else {
                          Navigator.pop(ctx);
                          if (mounted) _loadAll();
                        }
                      },
                      child: const Text('拉入'),
                    ),
                  )),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _handleRequest(User u, bool approve) async {
    final err = await Api.handleGroupRequest(widget.groupId, u.id, approve);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err ?? (approve ? '已通过' : '已拒绝'))));
    if (err == null) {
      _loadRequests();
      _loadAll();
    }
  }

  @override
  void dispose() {
    SocketService.leaveGroup(widget.groupId);
    _msgSub?.cancel();
    _chatScroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final g = _group;
    return Scaffold(
      appBar: AppBar(
        title: Text(g?.name ?? '小社区'),
        actions: [
          if (isMember && canManage)
            IconButton(icon: const Icon(Icons.settings_outlined), tooltip: '小社区设置', onPressed: _saveSettings),
          if (isMember && canManage)
            IconButton(icon: const Icon(Icons.person_add_alt), tooltip: '拉人进群', onPressed: _invite),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : g == null
              ? const Center(child: Text('小社区不存在或已解散', style: TextStyle(color: Colors.grey)))
              : Column(
                  children: [
                    // 群信息头
                    Container(
                      margin: const EdgeInsets.all(12),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Theme.of(context).cardColor,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          MakaAvatar(group: GroupBrief(id: g.id, name: g.name, avatar: g.avatar), size: 52),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Flexible(child: Text(g.name, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold))),
                                    if (g.joinApproval) ...[
                                      const SizedBox(width: 6),
                                      Text('需审核', style: TextStyle(fontSize: 11, color: Colors.grey[500])),
                                    ],
                                    if (!g.postsPublic) ...[
                                      const SizedBox(width: 6),
                                      Text('群动态仅成员可见', style: TextStyle(fontSize: 11, color: Colors.grey[500])),
                                    ],
                                  ],
                                ),
                                const SizedBox(height: 2),
                                Text(g.description?.isNotEmpty == true ? g.description! : '暂无简介', style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                                Text('${g.memberCount} 位成员 · ${formatTime(g.createdAt)}创建', style: TextStyle(fontSize: 11, color: Colors.grey[500])),
                              ],
                            ),
                          ),
                          if (isMember && !isOwner)
                            OutlinedButton(onPressed: _leave, style: OutlinedButton.styleFrom(visualDensity: VisualDensity.compact), child: const Text('退出'))
                          else if (!isMember)
                            FilledButton(onPressed: _join, style: FilledButton.styleFrom(visualDensity: VisualDensity.compact), child: const Text('加入'))
                          else
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(6)),
                              child: Text('群主', style: TextStyle(fontSize: 11, color: Theme.of(context).colorScheme.primary)),
                            ),
                        ],
                      ),
                    ),
                    // Tabs
                    SegmentedButton<int>(
                      segments: [
                        const ButtonSegment(value: 0, label: Text('动态')),
                        if (isMember) const ButtonSegment(value: 1, label: Text('群聊')),
                        if (isMember) const ButtonSegment(value: 2, label: Text('成员')),
                        if (canManage) ButtonSegment(value: 3, label: Badge(isLabelVisible: _pendingCount > 0, label: Text('$_pendingCount'), child: const Text('管理'))),
                      ],
                      selected: {_tab},
                      onSelectionChanged: (s) => setState(() => _tab = s.first),
                      style: SegmentedButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                        padding: const EdgeInsets.symmetric(horizontal: 6),
                      ),
                    ),
                    Expanded(child: _buildTab(context)),
                  ],
                ),
    );
  }

  Widget _buildTab(BuildContext context) {
    switch (_tab) {
      case 0: return _feedTab(context);
      case 1: return _chatTab(context);
      case 2: return _membersTab(context);
      case 3: return _manageTab(context);
      default: return _feedTab(context);
    }
  }

  Widget _feedTab(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _loadFeed,
      child: ListView(
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          if (isMember)
            GestureDetector(
              onTap: () async {
                final posted = await Navigator.push<bool>(context, MaterialPageRoute(builder: (_) => ComposerScreen(groupId: widget.groupId)));
                if (posted == true) _loadFeed();
              },
              child: Container(
                margin: const EdgeInsets.fromLTRB(12, 10, 12, 6),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
                decoration: BoxDecoration(
                  color: Theme.of(context).cardColor,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Row(
                  children: [
                    Icon(Icons.edit_note, color: Theme.of(context).colorScheme.primary),
                    const SizedBox(width: 8),
                    Text('分享点什么到小社区吧…', style: TextStyle(color: Colors.grey[500], fontSize: 14)),
                  ],
                ),
              ),
            ),
          if (_posts.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 50),
              child: Center(child: Text(isMember ? '小社区还没有动态，来发第一条吧' : ( _group!.postsPublic ? '小社区还没有公开动态' : '该社区动态仅成员可见'), style: TextStyle(color: Colors.grey[500]))),
            ),
          ..._posts.map((p) => PostCard(
                post: p,
                myId: _me?.id ?? 0,
                myIsAdmin: _me?.role == 'admin',
                onOpenComments: () async {
                  await Navigator.push(context, MaterialPageRoute(builder: (_) => PostDetailScreen(postId: p.id)));
                  _loadFeed();
                },
                onRemoved: _loadFeed,
                onChanged: _loadFeed,
              )),
        ],
      ),
    );
  }

  Widget _chatTab(BuildContext context) {
    final myId = _me?.id ?? 0;
    return Column(
      children: [
        Expanded(
          child: _chat.isEmpty
              ? Center(child: Text('群聊还是空的，说点什么吧～', style: TextStyle(color: Colors.grey[500])))
              : ListView.builder(
                  controller: _chatScroll,
                  padding: const EdgeInsets.all(12),
                  itemCount: _chat.length,
                  itemBuilder: (_, i) {
                    final m = _chat[i];
                    final mine = m.fromId == myId;
                    final name = m.author?.label ?? _members.where((x) => x.id == m.fromId).firstOrNull?.label ?? '用户#${m.fromId}';
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Column(
                        crossAxisAlignment: mine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (!mine) MakaAvatar(user: m.author ?? User(id: m.fromId, displayName: name), size: 22),
                              if (!mine) const SizedBox(width: 6),
                              Text(name, style: TextStyle(fontSize: 11, color: Colors.grey[600])),
                            ],
                          ),
                          const SizedBox(height: 2),
                          GestureDetector(
                            onLongPress: () => showMessageActions(
                              context,
                              canReport: !mine && m.id > 0,
                              canCopy: m.type == 'text' && m.content.isNotEmpty,
                              reportType: 'group_message',
                              messageId: m.id,
                              text: m.content,
                            ),
                            child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.72),
                            decoration: BoxDecoration(
                              color: mine ? Theme.of(context).colorScheme.primary : Theme.of(context).colorScheme.surfaceContainerHighest,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: ChatMediaContent(type: m.type, content: m.content, duration: m.duration, fromMe: mine),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
        ),
        if (isMember)
          ChatInputBar(onSend: _onChatSend)
        else
          SafeArea(
            top: false,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 14),
              color: Theme.of(context).cardColor,
              child: Text('加入小社区后即可参与群聊', textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey[600], fontSize: 13)),
            ),
          ),
      ],
    );
  }

  Widget _membersTab(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        Text('成员（${_members.length}）', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
        ..._members.map((u) => UserRow(
              user: u,
              sub: '#${u.id}',
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => UserProfileScreen(userId: u.id))),
              trailing: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: u.groupRole == 'owner' ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.1) : (u.groupRole == 'admin' ? Colors.green.withValues(alpha: 0.1) : null),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(_roleText(u), style: const TextStyle(fontSize: 11)),
                ),
              ],
            )),
      ],
    );
  }

  String _roleText(User u) {
    final role = u.groupRole;
    if (role == 'owner') return '群主';
    if (role == 'admin') return '管理员';
    return '成员';
  }

  Widget _manageTab(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        Card(
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14), side: BorderSide(color: Colors.grey.shade200)),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('小社区设置', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Row(
                  children: [
                    MakaAvatar(group: GroupBrief(id: _group!.id, name: _group!.name, avatar: _group!.avatar), size: 48),
                    const SizedBox(width: 12),
                    OutlinedButton(onPressed: _changeAvatar, child: const Text('更换头像')),
                    const Spacer(),
                    OutlinedButton(onPressed: _saveSettings, child: const Text('编辑设置')),
                  ],
                ),
              ],
            ),
          ),
        ),
        if (_pendingCount > 0)
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14), side: BorderSide(color: Colors.grey.shade200)),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('加入申请（$_pendingCount）', style: const TextStyle(fontWeight: FontWeight.bold)),
                  ..._requests.map((u) => Row(
                        children: [
                          Expanded(child: UserRow(user: u, sub: '#${u.id}')),
                          FilledButton.tonal(onPressed: () => _handleRequest(u, true), style: FilledButton.styleFrom(visualDensity: VisualDensity.compact), child: const Text('通过')),
                          const SizedBox(width: 8),
                          OutlinedButton(onPressed: () => _handleRequest(u, false), style: OutlinedButton.styleFrom(visualDensity: VisualDensity.compact), child: const Text('拒绝')),
                        ],
                      )),
                  if (_requests.isEmpty)
                    Padding(padding: const EdgeInsets.symmetric(vertical: 10), child: Text('暂无待处理的申请', style: TextStyle(color: Colors.grey[500], fontSize: 13))),
                ],
              ),
            ),
          ),
        if (isOwner)
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14), side: BorderSide(color: Colors.grey.shade200)),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Text('成员管理', style: TextStyle(fontWeight: FontWeight.bold)),
                      const Spacer(),
                      OutlinedButton.icon(onPressed: _invite, icon: const Icon(Icons.person_add_alt, size: 16), label: const Text('拉人进群')),
                    ],
                  ),
                  ..._members.where((u) => u.id != (_me?.id ?? -1)).map((u) {
                    final role = u.groupRole ?? 'member';
                    if (role == 'owner') {
                      return UserRow(user: u, sub: '#${u.id}', trailing: [Text('群主', style: TextStyle(fontSize: 11, color: Theme.of(context).colorScheme.primary))]);
                    }
                    return UserRow(
                      user: u,
                      sub: '#${u.id}',
                      trailing: [
                        OutlinedButton(
                          onPressed: () => _setAdmin(u, role != 'admin'),
                          style: OutlinedButton.styleFrom(visualDensity: VisualDensity.compact, minimumSize: const Size(0, 32), padding: const EdgeInsets.symmetric(horizontal: 10)),
                          child: Text(role == 'admin' ? '取消管理' : '设为管理', style: const TextStyle(fontSize: 12)),
                        ),
                        const SizedBox(width: 6),
                        OutlinedButton(
                          onPressed: () => _kick(u),
                          style: OutlinedButton.styleFrom(visualDensity: VisualDensity.compact, minimumSize: const Size(0, 32), padding: const EdgeInsets.symmetric(horizontal: 10), foregroundColor: Colors.red),
                          child: const Text('移出', style: TextStyle(fontSize: 12)),
                        ),
                      ],
                    );
                  }),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
