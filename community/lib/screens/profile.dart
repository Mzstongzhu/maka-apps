import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../api.dart';
import '../widgets/avatar.dart';
import 'login.dart';
import 'settings_screen.dart';
import 'friends_screen.dart';
import 'privacy_screen.dart';

class ProfileScreen extends StatefulWidget {
  final User? user;
  const ProfileScreen({super.key, this.user});
  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  User? _user;

  @override
  void initState() {
    super.initState();
    _user = widget.user;
    _loadUser();
  }

  Future<void> _loadUser() async {
    final u = await Api.getMe();
    if (mounted) setState(() => _user = u);
  }

  Future<void> _openSite() async {
    final uri = Uri.parse(BASE_URL);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _logout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('退出登录'),
        content: const Text('确定要退出登录吗？'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('确定')),
        ],
      ),
    );
    if (confirmed != true) return;
    SocketService.disconnect();
    await Api.clearToken();
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (_) => const LoginScreen()), (_) => false);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('我的')),
      body: ListView(
        children: [
          const SizedBox(height: 12),
          // 资料卡
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 12),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: cs.primaryContainer.withValues(alpha: 0.25),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                MakaAvatar(user: _user, size: 64),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(_user?.label ?? '用户', style: const TextStyle(fontSize: 19, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 4),
                      Text(
                        _user?.customId != null ? '@${_user!.customId}  ·  #${_user?.id ?? 0}' : '#${_user?.id ?? 0}  ·  ⭐ ${_user?.points ?? 0} 积分',
                        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          _item(Icons.people_alt_outlined, '我的好友', '好友列表与申请', () {
            Navigator.push(context, MaterialPageRoute(builder: (_) => const FriendsScreen()));
          }),
          _item(Icons.lock_outline, '隐私设置', '@、私信与好友权限', () {
            Navigator.push(context, MaterialPageRoute(builder: (_) => const PrivacyScreen()));
          }),
          _item(Icons.settings_outlined, '设置', '资料、密码、检查更新', () {
            Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsScreen())).then((_) => _loadUser());
          }),
          const Divider(),
          _item(Icons.open_in_new, '打开社区网页', BASE_URL.replaceFirst('https://', ''), _openSite),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: OutlinedButton.icon(
              onPressed: _logout,
              icon: const Icon(Icons.logout, color: Colors.red),
              label: const Text('退出登录', style: TextStyle(color: Colors.red)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _item(IconData icon, String title, String subtitle, VoidCallback onTap) {
    return ListTile(
      leading: Icon(icon),
      title: Text(title),
      subtitle: Text(subtitle, style: const TextStyle(fontSize: 12)),
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap,
    );
  }
}
