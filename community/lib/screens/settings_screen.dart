import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../api.dart';
import '../widgets/avatar.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});
  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  User? _me;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final u = await Api.getMe();
    if (!mounted) return;
    setState(() { _me = u; _loading = false; });
  }

  void _toast(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  // ---------- 编辑资料 ----------
  Future<void> _editProfile() async {
    final nameCtrl = TextEditingController(text: _me?.displayName ?? '');
    final bioCtrl = TextEditingController(text: _me?.bio ?? '');
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('编辑资料'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Center(
                child: GestureDetector(
                  onTap: () async {
                    XFile? x;
                    try {
                      final picker = ImagePicker();
                      x = await picker.pickImage(source: ImageSource.gallery, imageQuality: 80, maxWidth: 512);
                    } catch (e) {
                      if (ctx.mounted) {
                        ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text('打开相册失败: $e')));
                      }
                      return;
                    }
                    if (x == null) return;
                    if (ctx.mounted) {
                      ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(content: Text('正在上传头像…')));
                    }
                    final (url, upErr) = await Api.uploadImage(x.path, mime: x.mimeType);
                    if (url == null) {
                      if (ctx.mounted) {
                        ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text('头像上传失败：${upErr ?? "未知错误"}')));
                      }
                      return;
                    }
                    final err = await Api.updateProfile({'avatar': url});
                    if (err != null) {
                      if (ctx.mounted) {
                        ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text(err)));
                      }
                      return;
                    }
                    if (ctx.mounted) Navigator.pop(ctx, true);
                  },
                  child: MakaAvatar(user: _me, size: 64),
                ),
              ),
              const SizedBox(height: 6),
              Text('点击头像更换', style: TextStyle(fontSize: 11, color: Colors.grey[500])),
              const SizedBox(height: 12),
              TextField(
                controller: nameCtrl,
                maxLength: 20,
                decoration: const InputDecoration(labelText: '昵称', border: OutlineInputBorder(), counterText: ''),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: bioCtrl,
                maxLength: 200,
                maxLines: 3,
                decoration: const InputDecoration(labelText: '个人简介', border: OutlineInputBorder(), counterText: ''),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('保存')),
        ],
      ),
    );
    if (ok != true) return;
    final err = await Api.updateProfile({'display_name': nameCtrl.text.trim(), 'bio': bioCtrl.text.trim()});
    if (!mounted) return;
    if (err != null) {
      _toast(err);
    } else {
      _toast('资料已更新');
      _load();
    }
  }

  // ---------- 自定义 ID ----------
  Future<void> _editCustomId() async {
    final ctrl = TextEditingController(text: _me?.customId ?? '');
    final remaining = _me == null ? 0 : 7 * 24 * 3600 * 1000 - (DateTime.now().millisecondsSinceEpoch - _me!.customIdChangedAt);
    final onCooldown = _me != null && _me!.customId != null && _me!.customId!.isNotEmpty && remaining > 0;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('自定义 ID'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('3-20 位字母、数字或下划线，每 7 天可修改一次', style: TextStyle(fontSize: 12, color: Colors.grey[600])),
            if (onCooldown) ...[
              const SizedBox(height: 6),
              Text('冷却中，剩余 ${remaining ~/ 86400000 + 1} 天', style: const TextStyle(fontSize: 12, color: Colors.orange)),
            ],
            const SizedBox(height: 12),
            TextField(
              controller: ctrl,
              enabled: !onCooldown,
              decoration: const InputDecoration(labelText: '自定义 ID', border: OutlineInputBorder()),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
          FilledButton(onPressed: onCooldown ? null : () => Navigator.pop(ctx, true), child: const Text('保存')),
        ],
      ),
    );
    if (ok != true) return;
    final err = await Api.updateCustomId(ctrl.text.trim());
    if (!mounted) return;
    if (err != null) {
      _toast(err);
    } else {
      _toast('自定义 ID 已更新');
      _load();
    }
  }

  // ---------- 自定义头衔 ----------
  Future<void> _editTitle() async {
    final unlocked = _me?.titleUnlocked ?? false;
    if (!unlocked) {
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('解锁自定义头衔'),
          content: const Text('解锁需要消耗 500 积分，解锁后可自由设置头衔（最长 12 字）。'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('解锁（-500 积分）')),
          ],
        ),
      );
      if (ok != true) return;
      final err = await Api.unlockTitle();
      if (!mounted) return;
      if (err != null) {
        _toast(err);
        return;
      }
      _toast('解锁成功！');
      _load();
      if (mounted) _editTitle();
      return;
    }
    final ctrl = TextEditingController(text: _me?.title ?? '');
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('设置头衔'),
        content: TextField(
          controller: ctrl,
          maxLength: 12,
          decoration: const InputDecoration(labelText: '头衔（留空则清除）', border: OutlineInputBorder(), counterText: ''),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('保存')),
        ],
      ),
    );
    if (ok != true) return;
    final err = await Api.setTitle(ctrl.text.trim());
    if (!mounted) return;
    if (err != null) {
      _toast(err);
    } else {
      _toast('头衔已更新');
      _load();
    }
  }

  // ---------- 修改密码 ----------
  Future<void> _changePassword() async {
    final oldCtrl = TextEditingController();
    final newCtrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('修改密码'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: oldCtrl,
              obscureText: true,
              decoration: const InputDecoration(labelText: '原密码', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: newCtrl,
              obscureText: true,
              decoration: const InputDecoration(labelText: '新密码（至少 6 位）', border: OutlineInputBorder()),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('修改')),
        ],
      ),
    );
    if (ok != true) return;
    final err = await Api.changePassword(oldCtrl.text, newCtrl.text);
    if (!mounted) return;
    _toast(err ?? '密码已修改');
  }

  // ---------- 积分历史 ----------
  Future<void> _pointsHistory() async {
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder: (ctx) => FutureBuilder<List<PointsHistory>>(
        future: Api.getPointsHistory(),
        builder: (ctx, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Padding(padding: EdgeInsets.all(32), child: Center(child: CircularProgressIndicator()));
          }
          final items = snap.data ?? [];
          return Container(
            constraints: BoxConstraints(maxHeight: MediaQuery.of(ctx).size.height * 0.6),
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('积分记录（${items.length}）', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                const SizedBox(height: 8),
                if (items.isEmpty) const Padding(padding: EdgeInsets.all(24), child: Center(child: Text('暂无记录', style: TextStyle(color: Colors.grey)))),
                ...items.map((h) => ListTile(
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                      title: Text(h.reason, style: const TextStyle(fontSize: 14)),
                      subtitle: Text(formatTime(h.createdAt), style: const TextStyle(fontSize: 11)),
                      trailing: Text(
                        '${h.delta >= 0 ? '+' : ''}${h.delta}',
                        style: TextStyle(fontWeight: FontWeight.bold, color: h.delta >= 0 ? Colors.green : Colors.red),
                      ),
                    )),
              ],
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('设置')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              children: [
                const SizedBox(height: 8),
                // 资料卡
                ListTile(
                  leading: MakaAvatar(user: _me, size: 48),
                  title: Text(_me?.label ?? '', style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text('#${_me?.id ?? 0} · ⭐ ${_me?.points ?? 0} 积分'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: _editProfile,
                ),
                const Divider(),
                _item(context, Icons.badge_outlined, '自定义 ID', _me?.customId != null ? '@${_me!.customId}' : '未设置', _editCustomId),
                _item(context, Icons.style_outlined, '自定义头衔', (_me?.title != null && _me!.title!.isNotEmpty) ? _me!.title! : (_me?.titleUnlocked == true ? '已解锁' : '500 积分解锁'), _editTitle),
                _item(context, Icons.history, '积分记录', '查看明细', _pointsHistory),
                const Divider(),
                _item(context, Icons.lock_outline, '修改密码', '', _changePassword),
                _item(context, Icons.info_outline, '关于', '玛卡之声社区 v0.1.0', () {
                  showAboutDialog(context: context, applicationName: '玛卡之声社区', applicationVersion: '0.1.0', applicationLegalese: '玛卡之声社区 APP');
                }),
                const SizedBox(height: 16),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Text('积分可通过每日签到、发布动态等方式获得，头衔与自定义 ID 是社区身份的象征。', style: TextStyle(fontSize: 12, color: cs.outline)),
                ),
              ],
            ),
    );
  }

  Widget _item(BuildContext context, IconData icon, String title, String sub, VoidCallback onTap) {
    return ListTile(
      leading: Icon(icon),
      title: Text(title),
      subtitle: sub.isNotEmpty ? Text(sub, style: const TextStyle(fontSize: 12)) : null,
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap,
    );
  }
}
