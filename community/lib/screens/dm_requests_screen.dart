import 'package:flutter/material.dart';
import '../api.dart';
import '../widgets/avatar.dart';
import 'user_profile_screen.dart';
import 'chat.dart';

/// 消息申请箱：陌生人的首条私信需收件人同意后才能继续对话
class DmRequestsScreen extends StatefulWidget {
  const DmRequestsScreen({super.key});
  @override
  State<DmRequestsScreen> createState() => _DmRequestsScreenState();
}

class _DmRequestsScreenState extends State<DmRequestsScreen> {
  List<DmRequest> _in = [];
  List<DmRequest> _out = [];
  bool _loading = true;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final (list, out) = await (Api.getDmRequests(), Api.getDmRequestsOutgoing()).wait;
    if (!mounted) return;
    setState(() {
      _in = list;
      _out = out;
      _loading = false;
    });
  }

  Future<void> _accept(DmRequest r) async {
    if (_busy) return;
    setState(() => _busy = true);
    final err = await Api.acceptDmRequest(r.user.id);
    if (!mounted) return;
    setState(() => _busy = false);
    if (err != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err)));
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
      content: Text('已同意，可以开始聊天'), duration: Duration(milliseconds: 1200)));
    // 进入会话（申请语已作为首条私信落库）
    if (!mounted) return;
    Navigator.pushReplacement(context,
        MaterialPageRoute(builder: (_) => ChatScreen(peerId: r.user.id, peerName: r.user.label)));
  }

  Future<void> _ignore(DmRequest r) async {
    if (_busy) return;
    setState(() => _busy = true);
    final err = await Api.ignoreDmRequest(r.user.id);
    if (!mounted) return;
    setState(() => _busy = false);
    if (err != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err)));
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
      content: Text('已忽略；对方再次发消息时会重新进入申请箱'), duration: Duration(milliseconds: 1500)));
    _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('消息申请')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                children: [
                  if (_in.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                      child: Text('待确认（${_in.length}）',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.primary)),
                    ),
                  if (_in.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 56),
                      child: Center(
                        child: Column(children: [
                          Text('📭', style: TextStyle(fontSize: 36)),
                          SizedBox(height: 8),
                          Text('没有待确认的消息申请', style: TextStyle(color: Colors.grey, fontSize: 13)),
                        ]),
                      ),
                    ),
                  ..._in.map(_incomingTile),
                  if (_out.isNotEmpty) ...[
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
                      child: Text('等待对方确认（${_out.length}）',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey[600])),
                    ),
                    ..._out.map(_outgoingTile),
                  ],
                ],
              ),
            ),
    );
  }

  Widget _incomingTile(DmRequest r) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                GestureDetector(
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => UserProfileScreen(userId: r.user.id))),
                  child: MakaAvatar(user: r.user, size: 40),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(r.user.label, maxLines: 1, overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                      Text(formatTime(r.updatedAt), style: const TextStyle(fontSize: 11, color: Colors.grey)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(10)),
              child: Text(r.lastMessage, style: const TextStyle(fontSize: 14)),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(onPressed: _busy ? null : () => _ignore(r), child: const Text('忽略')),
                const SizedBox(width: 8),
                FilledButton.icon(
                  onPressed: _busy ? null : () => _accept(r),
                  icon: const Icon(Icons.check, size: 17),
                  label: const Text('同意并聊天'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _outgoingTile(DmRequest r) {
    return ListTile(
      leading: MakaAvatar(user: r.user, size: 40),
      title: Text(r.user.label, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text('${r.lastMessage}\n等待确认 · ${formatTime(r.updatedAt)}',
          maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12)),
      isThreeLine: true,
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => UserProfileScreen(userId: r.user.id))),
    );
  }
}
