import 'package:flutter/material.dart';
import 'admin_api.dart';
import 'screens/admin_home.dart';

void main() {
  runApp(const MakaAdminApp());
}

class MakaAdminApp extends StatelessWidget {
  const MakaAdminApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '玛卡管理面板',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF7C3AED)),
        useMaterial3: true,
      ),
      home: const AdminGate(),
      builder: (context, child) => DefaultTextStyle(
        style: DefaultTextStyle.of(context).style.copyWith(fontFamilyFallback: const ['Roboto', 'Noto Sans SC', 'PingFang SC', 'Microsoft YaHei']),
        child: child!,
      ),
    );
  }
}

/// 管理面板入口：自动恢复登录态，仅管理员可用
class AdminGate extends StatefulWidget {
  const AdminGate({super.key});
  @override
  State<AdminGate> createState() => _AdminGateState();
}

class _AdminGateState extends State<AdminGate> {
  bool _checking = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _restore();
  }

  Future<void> _restore() async {
    final err = await AdminApi.restore();
    if (!mounted) return;
    setState(() {
      _checking = false;
      _error = err;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_checking) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (_error == '未登录') return const AdminLoginScreen();
    // token 失效 / 无权限：回到登录页并提示
    return AdminLoginScreen(initialError: _error == '未登录' ? null : _error);
  }
}

class AdminLoginScreen extends StatefulWidget {
  final String? initialError;
  const AdminLoginScreen({super.key, this.initialError});
  @override
  State<AdminLoginScreen> createState() => _AdminLoginScreenState();
}

class _AdminLoginScreenState extends State<AdminLoginScreen> {
  final _account = TextEditingController();
  final _password = TextEditingController();
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _error = widget.initialError;
  }

  Future<void> _submit() async {
    final acc = _account.text.trim();
    final pwd = _password.text;
    if (acc.isEmpty || pwd.isEmpty) {
      setState(() => _error = '请输入账号和密码');
      return;
    }
    setState(() { _loading = true; _error = null; });
    final err = await AdminApi.login(acc, pwd);
    if (!mounted) return;
    if (err == null) {
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const AdminHome()));
    } else {
      setState(() { _loading = false; _error = err; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
          child: Column(
            children: [
              SizedBox(height: MediaQuery.of(context).size.height * 0.08),
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Icon(Icons.admin_panel_settings, size: 40),
              ),
              const SizedBox(height: 14),
              const Text('玛卡管理面板', style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Text('仅限管理员与协管员使用', style: TextStyle(color: Colors.grey[600], fontSize: 13)),
              const SizedBox(height: 36),
              TextField(
                controller: _account,
                decoration: const InputDecoration(labelText: '账号（识别码 / 自定义ID / 昵称）', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _password,
                decoration: const InputDecoration(labelText: '密码', border: OutlineInputBorder()),
                obscureText: true,
                onSubmitted: (_) => _submit(),
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(_error!, style: const TextStyle(color: Colors.red), textAlign: TextAlign.center),
              ],
              const SizedBox(height: 22),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: FilledButton.icon(
                  onPressed: _loading ? null : _submit,
                  icon: _loading
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.login),
                  label: Text(_loading ? '验证中…' : '进入管理面板'),
                ),
              ),
              const SizedBox(height: 14),
              Text('非管理员账号无法登录本应用', style: TextStyle(fontSize: 11, color: Colors.grey[500])),
            ],
          ),
        ),
      ),
    );
  }
}
