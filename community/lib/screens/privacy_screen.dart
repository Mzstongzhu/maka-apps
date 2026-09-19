import 'package:flutter/material.dart';
import '../api.dart';

/// 隐私设置：@、加好友、陌生人私信确认、免验证加好友
class PrivacyScreen extends StatefulWidget {
  const PrivacyScreen({super.key});
  @override
  State<PrivacyScreen> createState() => _PrivacyScreenState();
}

class _PrivacyScreenState extends State<PrivacyScreen> {
  PrivacySettings _p = PrivacySettings();
  bool _loading = true;
  String? _savingKey; // 正在保存的开关

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final p = await Api.getPrivacy();
    if (!mounted) return;
    setState(() { _p = p; _loading = false; });
  }

  Future<void> _toggle(String key, bool value) async {
    setState(() => _savingKey = key);
    final (np, err) = await Api.updatePrivacy({key: value});
    if (!mounted) return;
    setState(() => _savingKey = null);
    if (err != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('保存失败：$err')));
      return;
    }
    if (np != null) setState(() => _p = np);
  }

  Widget _switch({
    required String key,
    required IconData icon,
    required String title,
    required String subtitle,
    required bool value,
  }) {
    final busy = _savingKey == key;
    return SwitchListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16),
      secondary: Icon(icon, color: Theme.of(context).colorScheme.primary),
      title: Text(title, style: const TextStyle(fontSize: 15)),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 2),
        child: Text(subtitle, style: const TextStyle(fontSize: 12)),
      ),
      value: value,
      onChanged: busy ? null : (v) => _toggle(key, v),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('隐私设置')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              children: [
                const _SectionHeader('互动权限'),
                _switch(
                  key: 'allow_stranger_mention',
                  icon: Icons.alternate_email,
                  title: '允许陌生人 @ 我',
                  subtitle: '关闭后，非好友无法在动态正文中提到你',
                  value: _p.allowStrangerMention,
                ),
                _switch(
                  key: 'allow_stranger_friend',
                  icon: Icons.person_add_alt,
                  title: '允许陌生人添加好友',
                  subtitle: '关闭后，只有好友能向你发起好友申请',
                  value: _p.allowStrangerFriend,
                ),
                const Divider(height: 1),
                const _SectionHeader('私信'),
                _switch(
                  key: 'dm_confirm',
                  icon: Icons.mark_email_unread_outlined,
                  title: '陌生人私信需确认',
                  subtitle: '开启后，陌生人的首条私信进入"消息申请"，你同意后才能继续对话',
                  value: _p.dmConfirm,
                ),
                const Divider(height: 1),
                const _SectionHeader('好友验证'),
                _switch(
                  key: 'friend_auto_accept',
                  icon: Icons.verified_user_outlined,
                  title: '加好友不需要我同意',
                  subtitle: '开启后任何人加你为好友立即生效，请谨慎开启',
                  value: _p.friendAutoAccept,
                ),
                const SizedBox(height: 16),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  child: Text('所有隐私限制均由服务器强制执行，修改即时生效。',
                      style: TextStyle(fontSize: 12, color: Colors.grey)),
                ),
              ],
            ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String text;
  const _SectionHeader(this.text);
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Text(text, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.primary)),
    );
  }
}
