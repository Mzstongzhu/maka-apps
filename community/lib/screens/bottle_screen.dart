import 'package:flutter/material.dart';
import '../api.dart';

const _MOODS = ['普通', '开心', '难过', '愤怒', '祈祷', '神秘'];

class BottleScreen extends StatefulWidget {
  const BottleScreen({super.key});
  @override
  State<BottleScreen> createState() => _BottleScreenState();
}

class _BottleScreenState extends State<BottleScreen> {
  int _tab = 0; // 0 扔瓶子 1 我的瓶子
  final _throwCtrl = TextEditingController();
  String _mood = _MOODS[0];
  bool _throwing = false;
  bool _picking = false;
  Bottle? _current;
  List<Bottle> _thrown = [];
  List<Bottle> _picked = [];

  @override
  void initState() {
    super.initState();
    _loadMine();
  }

  Future<void> _loadMine() async {
    final (thrown, picked) = await Api.getMyBottles();
    if (!mounted) return;
    setState(() { _thrown = thrown; _picked = picked; });
  }

  Future<void> _throw() async {
    final t = _throwCtrl.text.trim();
    if (t.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('写点什么再扔吧')));
      return;
    }
    setState(() => _throwing = true);
    final err = await Api.throwBottle(t, _mood);
    if (!mounted) return;
    setState(() => _throwing = false);
    if (err != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err)));
    } else {
      _throwCtrl.clear();
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('瓶子已扔入大海 🌊')));
      _loadMine();
    }
  }

  Future<void> _pick() async {
    setState(() { _picking = true; _current = null; });
    final b = await Api.pickBottle();
    if (!mounted) return;
    setState(() { _picking = false; _current = b; });
    if (b == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('大海暂时空空如也，稍后再试')));
    }
  }

  Future<void> _keep(bool keepIt) async {
    final b = _current!;
    final err = await Api.keepBottle(b.id, keepIt);
    if (!mounted) return;
    if (err != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err)));
      return;
    }
    setState(() => _current = null);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(keepIt ? '已留下这个瓶子' : '已扔回大海')));
    _loadMine();
  }

  Future<void> _openReplies(Bottle b) async {
    final input = TextEditingController();
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) {
          List<BottleReply> replies = [];
          Future<void> load() async {
            final r = await Api.getBottleReplies(b.id);
            setSheet(() => replies = r);
          }
          load();
          return Padding(
            padding: EdgeInsets.fromLTRB(20, 20, 20, 20 + MediaQuery.of(ctx).viewInsets.bottom),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('瓶子对话', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
                const SizedBox(height: 10),
                Container(
                  constraints: const BoxConstraints(maxHeight: 320),
                  width: double.infinity,
                  child: replies.isEmpty
                      ? Center(child: Text('还没有回复', style: TextStyle(color: Colors.grey[500], fontSize: 13)))
                      : ListView.builder(
                          shrinkWrap: true,
                          itemCount: replies.length,
                          itemBuilder: (_, i) {
                            final r = replies[i];
                            return Padding(
                              padding: const EdgeInsets.symmetric(vertical: 3),
                              child: Column(
                                crossAxisAlignment: r.mine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                                children: [
                                  Text('${r.mine ? '我' : (r.role.isEmpty ? '对方' : r.role)} · ${formatTime(r.createdAt)}', style: TextStyle(fontSize: 10, color: Colors.grey[500])),
                                  const SizedBox(height: 2),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                    constraints: BoxConstraints(maxWidth: MediaQuery.of(ctx).size.width * 0.7),
                                    decoration: BoxDecoration(
                                      color: r.mine ? Theme.of(ctx).colorScheme.primary : Theme.of(ctx).colorScheme.surfaceContainerHighest,
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Text(r.content, style: TextStyle(fontSize: 14, color: r.mine ? Colors.white : null)),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: input,
                        decoration: const InputDecoration(hintText: '回复对方（匿名）', isDense: true, border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(22)))),
                        onSubmitted: (_) async {
                          final t = input.text.trim();
                          if (t.isEmpty) return;
                          final err = await Api.replyBottle(b.id, t);
                          if (err == null) {
                            input.clear();
                            load();
                          } else if (ctx.mounted) {
                            ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text(err)));
                          }
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton.filled(
                      onPressed: () async {
                        final t = input.text.trim();
                        if (t.isEmpty) return;
                        final err = await Api.replyBottle(b.id, t);
                        if (err == null) {
                          input.clear();
                          load();
                        } else if (ctx.mounted) {
                          ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text(err)));
                        }
                      },
                      icon: const Icon(Icons.send, size: 18),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  String _statusText(String s) => switch (s) {
        'sea' => '漂流中',
        'picked' => '被捞起',
        _ => '已被收藏',
      };

  @override
  void dispose() {
    _throwCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('漂流瓶')),
      body: RefreshIndicator(
        onRefresh: _loadMine,
        child: ListView(
          padding: const EdgeInsets.all(12),
          children: [
            // 大海卡片
            Container(
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                gradient: const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFFEFF6FF), Color(0xFFECFEFF)]),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.cyan.shade100),
              ),
              child: Column(
                children: [
                  const Text('🌊 漂流瓶', style: TextStyle(fontSize: 19, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text('把心事装进瓶子扔进大海，也许会被陌生人捞起', style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                  const SizedBox(height: 14),
                  FilledButton.icon(
                    onPressed: _picking ? null : _pick,
                    icon: _picking ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.phishing_outlined),
                    label: Text(_picking ? '打捞中…' : '捞一个瓶子'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            SegmentedButton<int>(
              segments: const [
                ButtonSegment(value: 0, label: Text('扔瓶子')),
                ButtonSegment(value: 1, label: Text('我的瓶子')),
              ],
              selected: {_tab},
              onSelectionChanged: (s) => setState(() => _tab = s.first),
            ),
            const SizedBox(height: 10),
            if (_tab == 0)
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Theme.of(context).cardColor,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('✍️ 扔一个瓶子', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _throwCtrl,
                      maxLines: 4,
                      maxLength: 1000,
                      decoration: const InputDecoration(
                        hintText: '此刻的心情、想说的话…（匿名投递）',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    Row(
                      children: [
                        DropdownButton<String>(
                          value: _mood,
                          items: _MOODS.map((m) => DropdownMenuItem(value: m, child: Text(m))).toList(),
                          onChanged: (v) => setState(() => _mood = v ?? _mood),
                          underline: const SizedBox.shrink(),
                        ),
                        const Spacer(),
                        FilledButton(onPressed: _throwing ? null : _throw, child: Text(_throwing ? '投递中…' : '扔进大海')),
                      ],
                    ),
                  ],
                ),
              )
            else
              ...[
                _bottleList('我扔出的（${_thrown.length}）', _thrown, showStatus: true),
                _bottleList('我捞到的（${_picked.length}）', _picked, showReplies: true),
              ],
          ],
        ),
      ),
      // 刚捞到的瓶子
      bottomSheet: _current != null
          ? Container(
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.15), blurRadius: 20)],
              ),
              padding: const EdgeInsets.all(20),
              child: SafeArea(
                top: false,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(colors: [Color(0xFFECFEFF), Color(0xFFEFF6FF)]),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: Colors.cyan.shade100),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Align(
                            alignment: Alignment.topRight,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(color: Colors.grey.shade200, borderRadius: BorderRadius.circular(6)),
                              child: Text(_current!.mood, style: const TextStyle(fontSize: 11)),
                            ),
                          ),
                          Text(_current!.content, style: const TextStyle(fontSize: 15, height: 1.5)),
                          const SizedBox(height: 6),
                          Text('匿名漂流瓶 · ${formatTime(_current!.thrownAt)}', style: TextStyle(fontSize: 11, color: Colors.grey[600])),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(child: OutlinedButton(onPressed: () => _keep(false), child: const Text('🌊 扔回大海'))),
                        const SizedBox(width: 10),
                        Expanded(child: FilledButton(onPressed: () => _keep(true), child: const Text('💬 留下并回复'))),
                      ],
                    ),
                  ],
                ),
              ),
            )
          : null,
    );
  }

  Widget _bottleList(String title, List<Bottle> items, {bool showStatus = false, bool showReplies = false}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(padding: const EdgeInsets.fromLTRB(14, 12, 14, 4), child: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14))),
          if (items.isEmpty)
            Padding(padding: const EdgeInsets.fromLTRB(14, 4, 14, 14), child: Text(showStatus ? '还没有扔过瓶子' : '还没有捞到过瓶子', style: TextStyle(color: Colors.grey[500], fontSize: 13))),
          ...items.map((b) => Padding(
                padding: const EdgeInsets.fromLTRB(14, 4, 14, 4),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(6)),
                      child: Text(b.mood, style: const TextStyle(fontSize: 11)),
                    ),
                    const SizedBox(width: 8),
                    Expanded(child: Text(b.content, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13))),
                    if (showStatus)
                      Text(_statusText(b.status), style: TextStyle(fontSize: 11, color: b.status == 'sea' ? Colors.green : Colors.grey[500])),
                    if (showReplies)
                      OutlinedButton(
                        onPressed: () => _openReplies(b),
                        style: OutlinedButton.styleFrom(visualDensity: VisualDensity.compact, minimumSize: const Size(0, 30), padding: const EdgeInsets.symmetric(horizontal: 10)),
                        child: const Text('回复', style: TextStyle(fontSize: 12)),
                      ),
                  ],
                ),
              )),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}
