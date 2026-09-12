import 'package:flutter/material.dart';
import '../admin_api.dart';

/// 用户管理：仅官方管理员（识别码 10000000）
class UsersScreen extends StatefulWidget {
  const UsersScreen({super.key});
  @override
  State<UsersScreen> createState() => _UsersScreenState();
}

class _UsersScreenState extends State<UsersScreen> with AutomaticKeepAliveClientMixin {
  final _search = TextEditingController();
  List<AdminUser> _items = [];
  bool _loading = false;
  String? _error;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _load('');
  }

  Future<void> _load(String q) async {
    setState(() { _loading = true; _error = null; });
    final (items, err) = await AdminApi.searchUsers(q);
    if (!mounted) return;
    setState(() { _items = items; _loading = false; _error = err; });
  }

  void _snack(String? err, {String okMsg = '操作成功'}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err ?? okMsg)));
  }

  Future<void> _confirm(String title, String content, Future<void> Function() run) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(content),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('确定')),
        ],
      ),
    );
    if (ok != true) return;
    await run();
  }

  void _openUser(AdminUser u) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(children: [
                CircleAvatar(child: Text(u.displayName.isNotEmpty ? u.displayName[0] : '?')),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('${u.displayName}（${u.id}）', style: const TextStyle(fontWeight: FontWeight.bold)),
                      Text('${u.customId.isNotEmpty ? '@${u.customId} · ' : ''}${u.statusLabel} · ${u.role == 'admin' ? '协管员' : '用户'} · 积分 ${u.points}',
                          style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                    ],
                  ),
                ),
              ]),
              const Divider(height: 24),
              ListTile(
                leading: const Icon(Icons.volume_off),
                title: const Text('禁言 1 天'),
                onTap: () {
                  Navigator.pop(ctx);
                  _confirm('禁言用户', '确定将 ${u.displayName} 禁言 1 天吗？', () async {
                    final err = await AdminApi.setUserStatus(u.id, 'muted', days: 1);
                    _snack(err);
                    _load(_search.text);
                  });
                },
              ),
              ListTile(
                leading: const Icon(Icons.volume_mute),
                title: const Text('禁言 7 天'),
                onTap: () {
                  Navigator.pop(ctx);
                  _confirm('禁言用户', '确定将 ${u.displayName} 禁言 7 天吗？', () async {
                    final err = await AdminApi.setUserStatus(u.id, 'muted', days: 7);
                    _snack(err);
                    _load(_search.text);
                  });
                },
              ),
              ListTile(
                leading: const Icon(Icons.block),
                title: const Text('封禁账号'),
                onTap: () {
                  Navigator.pop(ctx);
                  _confirm('封禁账号', '确定封禁 ${u.displayName} 吗？封禁后该用户将无法登录。', () async {
                    final err = await AdminApi.setUserStatus(u.id, 'banned');
                    _snack(err);
                    _load(_search.text);
                  });
                },
              ),
              if (u.status != 'active')
                ListTile(
                  leading: const Icon(Icons.check_circle),
                  title: const Text('解除限制'),
                  onTap: () {
                    Navigator.pop(ctx);
                    _confirm('解除限制', '确定恢复 ${u.displayName} 的正常状态吗？', () async {
                      final err = await AdminApi.setUserStatus(u.id, 'active');
                      _snack(err);
                      _load(_search.text);
                    });
                  },
                ),
              ListTile(
                leading: const Icon(Icons.stars),
                title: const Text('调整积分'),
                subtitle: const Text('增加/减少或直接设置余额', style: TextStyle(fontSize: 12)),
                onTap: () {
                  Navigator.pop(ctx);
                  _pointsDialog(u);
                },
              ),
              ListTile(
                leading: Icon(u.role == 'admin' ? Icons.remove_moderator : Icons.add_moderator),
                title: Text(u.role == 'admin' ? '罢免协管员' : '任命为协管员'),
                onTap: () {
                  Navigator.pop(ctx);
                  final toAdmin = u.role != 'admin';
                  _confirm(
                    toAdmin ? '任命协管员' : '罢免协管员',
                    toAdmin ? '任命后该用户可在管理面板处理举报。' : '罢免后该用户将失去管理权限。',
                    () async {
                      final err = await AdminApi.setRole(u.id, toAdmin ? 'admin' : 'user');
                      _snack(err);
                      _load(_search.text);
                    },
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.verified),
                title: Text(u.officialBadge ? '收回官方头衔' : '颁发官方头衔'),
                onTap: () {
                  Navigator.pop(ctx);
                  _confirm('官方头衔', '确定${u.officialBadge ? '收回' : '颁发'}官方头衔吗？', () async {
                    final err = await AdminApi.setOfficialBadge(u.id, !u.officialBadge);
                    _snack(err);
                    _load(_search.text);
                  });
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _pointsDialog(AdminUser u) async {
    final modeCtrl = TextEditingController(text: 'add');
    final amountCtrl = TextEditingController();
    final reasonCtrl = TextEditingController();
    String mode = 'add';
    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: Text('调整积分 · ${u.displayName}（当前 ${u.points}）'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: 'add', label: Text('增加')),
                  ButtonSegment(value: 'set', label: Text('设为')),
                ],
                selected: {mode},
                onSelectionChanged: (s) => setLocal(() => mode = s.first),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: amountCtrl,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(labelText: mode == 'add' ? '变动数量（可为负）' : '目标余额'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: reasonCtrl,
                decoration: const InputDecoration(labelText: '备注原因（可选）'),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
            TextButton(
              onPressed: () async {
                final amount = int.tryParse(amountCtrl.text.trim());
                if (amount == null) {
                  _snack('积分必须为整数');
                  return;
                }
                Navigator.pop(ctx);
                final err = await AdminApi.setPoints(u.id, mode: mode, amount: amount, reason: reasonCtrl.text.trim());
                _snack(err, okMsg: '积分已更新');
                _load(_search.text);
              },
              child: const Text('确定'),
            ),
          ],
        ),
      ),
    );
    modeCtrl.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _search,
                  decoration: const InputDecoration(
                    hintText: '输入识别码 / 自定义ID / 昵称搜索',
                    prefixIcon: Icon(Icons.search),
                    isDense: true,
                    border: OutlineInputBorder(),
                  ),
                  onSubmitted: _load,
                ),
              ),
              const SizedBox(width: 8),
              IconButton.filled(
                onPressed: () => _load(_search.text.trim()),
                icon: const Icon(Icons.search),
              ),
            ],
          ),
        ),
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _error != null
                  ? Center(child: Text(_error!, style: const TextStyle(color: Colors.red)))
                  : _items.isEmpty
                      ? const Center(child: Text('搜索用户后进行管理', style: TextStyle(color: Colors.grey)))
                      : ListView.builder(
                          itemCount: _items.length,
                          itemBuilder: (ctx, i) {
                            final u = _items[i];
                            return ListTile(
                              leading: CircleAvatar(
                                child: Text(u.displayName.isNotEmpty ? u.displayName[0] : '?'),
                              ),
                              title: Text('${u.displayName}${u.isOfficial ? '（官方管理员）' : u.role == 'admin' ? '（协管员）' : ''}'),
                              subtitle: Text('${u.id}${u.customId.isNotEmpty ? ' · @${u.customId}' : ''} · ${u.statusLabel} · 积分 ${u.points}'),
                              trailing: const Icon(Icons.chevron_right),
                              onTap: () => _openUser(u),
                            );
                          },
                        ),
        ),
      ],
    );
  }
}
