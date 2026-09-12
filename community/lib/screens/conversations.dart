import 'package:flutter/material.dart';
import '../api.dart';
import 'new_chat.dart';

class ConversationsScreen extends StatefulWidget {
  final void Function(int peerId, String peerName)? onOpenChat;
  const ConversationsScreen({super.key, this.onOpenChat});
  @override
  State<ConversationsScreen> createState() => ConversationsScreenState();
}

class ConversationsScreenState extends State<ConversationsScreen> with AutomaticKeepAliveClientMixin {
  List<Conversation> _items = [];
  bool _loading = true;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    refresh();
  }

  Future<void> refresh() async {
    final items = await Api.getConversations();
    if (!mounted) return;
    setState(() { _items = items; _loading = false; });
  }

  void _openNewChat() {
    Navigator.push(context, MaterialPageRoute(
      builder: (_) => NewChatScreen(onPick: (id, name) => widget.onOpenChat?.call(id, name)),
    ));
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('私信'),
        actions: [
          IconButton(
            tooltip: '发起私信',
            icon: const Icon(Icons.edit_square),
            onPressed: _openNewChat,
          ),
        ],
      ),
      floatingActionButton: _loading || _items.isNotEmpty
          ? null
          : FloatingActionButton.extended(
              onPressed: _openNewChat,
              icon: const Icon(Icons.edit_square),
              label: const Text('发起私信'),
            ),
      body: RefreshIndicator(
        onRefresh: refresh,
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _items.isEmpty
                ? ListView(
                    children: const [
                      SizedBox(height: 200),
                      Center(child: Text('暂无私信，点击下方按钮发起', style: TextStyle(color: Colors.grey))),
                    ],
                  )
                : ListView.builder(
                    itemCount: _items.length,
                    itemBuilder: (ctx, i) {
                      final c = _items[i];
                      final preview = c.lastFromMe ? '我: ${c.lastMessage}' : c.lastMessage;
                      return ListTile(
                        leading: CircleAvatar(
                          backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                          child: Text(c.peerName.isNotEmpty ? c.peerName[0] : '?'),
                        ),
                        title: Text(c.peerName, style: TextStyle(fontWeight: c.unread > 0 ? FontWeight.bold : FontWeight.normal)),
                        subtitle: Text(preview, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: c.unread > 0 ? null : Colors.grey)),
                        trailing: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(formatTime(c.lastTime), style: const TextStyle(fontSize: 12, color: Colors.grey)),
                            if (c.unread > 0)
                              Container(
                                margin: const EdgeInsets.only(top: 4),
                                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                decoration: BoxDecoration(color: Colors.red, borderRadius: BorderRadius.circular(10)),
                                child: Text('${c.unread}', style: const TextStyle(color: Colors.white, fontSize: 11)),
                              ),
                          ],
                        ),
                        onTap: () => widget.onOpenChat?.call(c.peerId, c.peerName),
                      );
                    },
                  ),
      ),
    );
  }
}
