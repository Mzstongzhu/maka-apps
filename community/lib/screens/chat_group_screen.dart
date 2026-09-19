import 'dart:async';
import 'package:flutter/material.dart';
import '../api.dart';
import 'user_profile_screen.dart';
import 'chat_group_profile_screen.dart';
import '../widgets/chat_media.dart';
import '../widgets/chat_input.dart';
import '../widgets/message_actions.dart';

/// 聊天群组会话页（T15 文本；图片/语音/视频 T16 扩展）
class ChatGroupScreen extends StatefulWidget {
  final int groupId;
  final String groupName;
  const ChatGroupScreen({super.key, required this.groupId, required this.groupName});
  @override
  State<ChatGroupScreen> createState() => _ChatGroupScreenState();
}

class _ChatGroupScreenState extends State<ChatGroupScreen> {
  final _scroll = ScrollController();
  final List<ChatMessage> _messages = [];
  bool _loading = true;
  int? _myId;
  int _memberCount = 0;
  String _name = '';
  StreamSubscription? _msgSub;

  @override
  void initState() {
    super.initState();
    _name = widget.groupName;
    _load();
    // 群内任意成员（含自己）的消息
    _msgSub = SocketService.chatMsgStream.listen((msg) {
      final gid = msg['group_id'] as int? ?? 0;
      if (gid != widget.groupId) return;
      final m = ChatMessage.fromJson(msg);
      if (m.id > 0 && _messages.any((e) => e.id == m.id)) return;
      setState(() {
        // 替换自己的本地乐观消息
        if (m.fromId == _myId) {
          _messages.removeWhere((e) => e.id < 0 && e.fromId == _myId && e.content == m.content && e.type == m.type);
        }
        _messages.add(m);
      });
      _scrollToBottom();
      // 他人消息：拉取接口顺带更新已读位
      if (_myId != null && m.fromId != _myId) {
        Api.getChatMessages(widget.groupId);
      }
    });
  }

  Future<void> _load() async {
    final results = await Future.wait([
      Api.getChatMessages(widget.groupId),
      Api.getMe(),
    ]);
    if (!mounted) return;
    final msgs = results[0] as List<ChatMessage>;
    final me = results[1] as User?;
    // 群资料（成员数），失败不阻塞
    final detail = await Api.getChatGroup(widget.groupId);
    if (!mounted) return;
    setState(() {
      _messages
        ..clear()
        ..addAll(msgs);
      _myId = me?.id;
      _loading = false;
      if (detail != null) {
        _memberCount = detail.members.length;
        _name = detail.group.name;
      }
    });
    _scrollToBottom();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) _scroll.jumpTo(_scroll.position.maxScrollExtent);
    });
  }

  Future<String?> _onInputSend(String type, String content, int duration) async {
    final temp = ChatMessage(
      id: -DateTime.now().millisecondsSinceEpoch,
      groupId: widget.groupId,
      fromId: _myId ?? 0,
      content: content,
      type: type,
      duration: duration,
      createdAt: DateTime.now().millisecondsSinceEpoch,
      from: _myId == null ? null : User(id: _myId!),
    );
    setState(() => _messages.add(temp));
    _scrollToBottom();
    final (_, err) = await Api.sendChatMessage(widget.groupId,
        type: type, content: content, duration: duration);
    if (err != null && mounted) {
      setState(() => _messages.removeWhere((m) => m.id == temp.id));
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err)));
      return err;
    }
    // 成功后 chat:msg 会带来真实消息（自己也在成员列表内）
    return null;
  }

  Future<void> _openProfile() async {
    await Navigator.push(context, MaterialPageRoute(
      builder: (_) => ChatGroupProfileScreen(groupId: widget.groupId),
    ));
    if (!mounted) return;
    // 资料可能被修改/自己被踢，重新拉取；若已非成员则返回
    final detail = await Api.getChatGroup(widget.groupId);
    if (!mounted) return;
    if (detail == null) {
      Navigator.pop(context);
      return;
    }
    setState(() {
      _name = detail.group.name;
      _memberCount = detail.members.length;
    });
  }

  @override
  void dispose() {
    _msgSub?.cancel();
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(_name, maxLines: 1, overflow: TextOverflow.ellipsis),
            Text(_memberCount > 0 ? '$_memberCount 位成员' : '聊天群组',
                style: const TextStyle(fontSize: 11, color: Colors.white70)),
          ],
        ),
        actions: [
          IconButton(icon: const Icon(Icons.more_horiz), onPressed: _openProfile),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _messages.isEmpty
                    ? const Center(child: Text('暂无消息，发送第一条吧', style: TextStyle(color: Colors.grey)))
                    : ListView.builder(
                        controller: _scroll,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        itemCount: _messages.length,
                        itemBuilder: (ctx, i) {
                          final m = _messages[i];
                          final fromMe = m.fromId == _myId;
                          // 他人连续消息只在第一条显示昵称
                          bool showName = !fromMe;
                          if (showName && i > 0) {
                            final prev = _messages[i - 1];
                            if (prev.fromId == m.fromId) showName = false;
                          }
                          return _bubble(m, fromMe, showName);
                        },
                      ),
          ),
          ChatInputBar(onSend: _onInputSend),
        ],
      ),
    );
  }

  Widget _bubble(ChatMessage m, bool fromMe, bool showName) {
    final url = absUrl(m.from?.avatar);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: fromMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!fromMe)
            GestureDetector(
              onTap: m.from == null
                  ? null
                  : () => Navigator.push(context, MaterialPageRoute(
                      builder: (_) => UserProfileScreen(userId: m.from!.id))),
              child: CircleAvatar(
                radius: 16,
                backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                backgroundImage: url.isEmpty ? null : NetworkImage(url),
                child: url.isEmpty
                    ? Text((m.from?.label ?? '?').isNotEmpty ? (m.from?.label ?? '?')[0] : '?',
                        style: const TextStyle(fontSize: 12))
                    : null,
              ),
            )

          else
            const SizedBox(width: 32),
          const SizedBox(width: 8),
          Flexible(
            child: Column(
              crossAxisAlignment: fromMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                if (showName && m.from != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 2, left: 4),
                    child: Text(m.from!.label,
                        style: const TextStyle(fontSize: 11, color: Colors.grey)),
                  ),
                GestureDetector(
                  onLongPress: () => showMessageActions(
                    context,
                    canReport: !fromMe && m.id > 0,
                    canCopy: m.type == 'text' && m.content.isNotEmpty,
                    reportType: 'chat_message',
                    messageId: m.id,
                    text: m.content,
                  ),
                  child: Container(
                  constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.68),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                  decoration: BoxDecoration(
                    color: fromMe
                        ? Theme.of(context).colorScheme.primary
                        : Theme.of(context).colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(16),
                      topRight: const Radius.circular(16),
                      bottomLeft: fromMe ? const Radius.circular(16) : Radius.zero,
                      bottomRight: fromMe ? Radius.zero : const Radius.circular(16),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      ChatMediaContent(type: m.type, content: m.content, duration: m.duration, fromMe: fromMe),
                      const SizedBox(height: 2),
                      Text(formatTime(m.createdAt),
                          style: TextStyle(color: fromMe ? Colors.white70 : Colors.grey, fontSize: 11)),
                    ],
                  ),
                  ),
                ),
              ],
            ),
          ),
          if (fromMe) const SizedBox(width: 32) else const SizedBox(width: 8),
        ],
      ),
    );
  }
}
