import 'dart:async';
import 'package:flutter/material.dart';
import '../api.dart';

class ChatScreen extends StatefulWidget {
  final int peerId;
  final String peerName;
  const ChatScreen({super.key, required this.peerId, required this.peerName});
  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _input = TextEditingController();
  final _scroll = ScrollController();
  final List<Message> _messages = [];
  bool _loading = true;
  bool _sending = false;
  int? _myId;
  int _tempSeq = -1; // 本地乐观消息的临时负数 id
  StreamSubscription? _newSub;
  StreamSubscription? _sentSub;
  StreamSubscription? _readSub;

  @override
  void initState() {
    super.initState();
    _load();
    // 对方发来的新消息
    _newSub = SocketService.dmStream.listen((msg) {
      final fromId = msg['from_id'] as int? ?? 0;
      if (fromId != widget.peerId) return;
      _addIfAbsent(Message.fromJson(msg));
      // 正在会话窗口内：通知服务端已读，服务端会给对方推 dm:read 回执
      Api.getMessages(widget.peerId);
    });
    // 自己发送成功的回执（带真实 id），替换本地乐观消息
    _sentSub = SocketService.sentStream.listen((msg) {
      final toId = msg['to_id'] as int? ?? 0;
      if (toId != widget.peerId) return;
      setState(() {
        _messages.removeWhere((m) => m.id < 0 && m.fromId == (_myId ?? 0) && m.content == (msg['content'] ?? ''));
        final realId = msg['id'] as int? ?? 0;
        if (!_messages.any((m) => m.id == realId && realId > 0)) {
          _messages.add(Message.fromJson(msg));
        }
        _messages.sort((a, b) => a.createdAt.compareTo(b.createdAt));
      });
      _scrollToBottom();
    });
    // 对方已读了我发的消息
    _readSub = SocketService.readStream.listen((data) {
      final reader = data['reader'] as int? ?? 0;
      if (reader != widget.peerId) return;
      final ids = (data['ids'] as List?)?.map((e) => e as int).toSet() ?? <int>{};
      if (ids.isEmpty) return;
      setState(() {
        for (final m in _messages) {
          if (m.fromId == (_myId ?? 0) && ids.contains(m.id) && m.readAt == 0) {
            m.readAt = DateTime.now().millisecondsSinceEpoch;
          }
        }
      });
    });
  }

  void _addIfAbsent(Message m) {
    if (m.id > 0 && _messages.any((e) => e.id == m.id)) return;
    setState(() => _messages.add(m));
    _scrollToBottom();
  }

  Future<void> _load() async {
    // getMessages 内部会把对方发来的未读标记已读，并向对方推送 dm:read
    final msgs = await Api.getMessages(widget.peerId);
    final me = await Api.getMe();
    if (!mounted) return;
    setState(() { _messages
      ..clear()
      ..addAll(msgs);
      _loading = false;
      _myId = me?.id;
    });
    _scrollToBottom();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) _scroll.jumpTo(_scroll.position.maxScrollExtent);
    });
  }

  Future<void> _send() async {
    final text = _input.text.trim();
    if (text.isEmpty || _sending) return;
    _input.clear();
    final temp = Message(
      id: _tempSeq--,
      fromId: _myId ?? 0,
      toId: widget.peerId,
      content: text,
      createdAt: DateTime.now().millisecondsSinceEpoch,
    );
    setState(() { _sending = true; _messages.add(temp); });
    _scrollToBottom();
    final err = await Api.sendMessage(widget.peerId, text);
    if (!mounted) return;
    if (err != null) {
      setState(() {
        _messages.removeWhere((m) => m.id == temp.id);
        _input.text = text;
      });
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err)));
    }
    // 成功后由 dm:sent 回执替换乐观消息（即使 socket 暂时未到，下次进会话也会以真实消息为准）
    setState(() => _sending = false);
  }

  @override
  void dispose() {
    _newSub?.cancel();
    _sentSub?.cancel();
    _readSub?.cancel();
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // 最后一条自己发出的消息，用于显示 已读/未读
    int? lastMineId;
    for (var i = _messages.length - 1; i >= 0; i--) {
      if (_messages[i].fromId == _myId) { lastMineId = _messages[i].id; break; }
    }
    return Scaffold(
      appBar: AppBar(title: Text(widget.peerName)),
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
                          final showRead = fromMe && m.id == lastMineId;
                          return _bubble(m, fromMe, showRead);
                        },
                      ),
          ),
          _inputBar,
        ],
      ),
    );
  }

  Widget _bubble(Message m, bool fromMe, bool showRead) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: fromMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: [
          if (fromMe) const SizedBox(width: 48),
          Flexible(
            child: Container(
              constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.72),
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
                  Text(m.content, style: TextStyle(color: fromMe ? Colors.white : null, fontSize: 15)),
                  const SizedBox(height: 2),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (showRead)
                        Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: Text(
                            m.readAt > 0 ? '已读' : '未读',
                            style: TextStyle(
                              color: fromMe
                                  ? (m.readAt > 0 ? Colors.white70 : Colors.amberAccent.shade100)
                                  : Colors.grey,
                              fontSize: 11,
                            ),
                          ),
                        ),
                      Text(formatTime(m.createdAt), style: TextStyle(color: fromMe ? Colors.white70 : Colors.grey, fontSize: 11)),
                    ],
                  ),
                ],
              ),
            ),
          ),
          if (!fromMe) const SizedBox(width: 48),
        ],
      ),
    );
  }

  Widget get _inputBar => SafeArea(
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _input,
              decoration: const InputDecoration(
                hintText: '输入消息…',
                border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(24))),
                contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              ),
              onSubmitted: (_) => _send(),
            ),
          ),
          const SizedBox(width: 8),
          IconButton.filled(
            onPressed: _sending ? null : _send,
            icon: _sending
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.send),
          ),
        ],
      ),
    ),
  );
}
