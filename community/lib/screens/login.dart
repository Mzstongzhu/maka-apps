import 'package:flutter/material.dart';
import '../api.dart';
import 'main_page.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _account = TextEditingController();
  final _password = TextEditingController();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password2 = TextEditingController();
  bool _loading = false;
  bool _registerMode = false;
  String? _error;

  Future<void> _submit() async {
    final acc = _account.text.trim();
    final pwd = _password.text;
    if (!_registerMode && (acc.isEmpty || pwd.isEmpty)) {
      setState(() => _error = '请输入账号和密码');
      return;
    }
    setState(() { _loading = true; _error = null; });

    if (_registerMode) {
      final name = _name.text.trim();
      final email = _email.text.trim();
      if (name.isEmpty || pwd.isEmpty) {
        setState(() { _loading = false; _error = '请填写昵称和密码'; });
        return;
      }
      if (pwd.length < 6) {
        setState(() { _loading = false; _error = '密码至少 6 位'; });
        return;
      }
      if (pwd != _password2.text) {
        setState(() { _loading = false; _error = '两次输入的密码不一致'; });
        return;
      }
      final (user, err) = await Api.register(name, pwd, email);
      if (!mounted) return;
      if (user != null) {
        SocketService.connect(Api.token!);
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const MainScreen()));
        return;
      }
      setState(() { _loading = false; _error = err ?? '注册失败，请稍后再试'; });
      return;
    }

    final (user, err) = await Api.login(acc, pwd);
    if (!mounted) return;
    if (user != null) {
      SocketService.connect(Api.token!);
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const MainScreen()));
    } else {
      setState(() { _loading = false; _error = err ?? '登录失败，请检查账号和密码'; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SizedBox(height: _registerMode ? 24 : 0),
              Icon(Icons.forum, size: 64, color: Theme.of(context).colorScheme.primary),
              const SizedBox(height: 12),
              const Text('玛卡之声社区', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Text(_registerMode ? '注册新账号，加入社区大家庭' : '浏览社区、收发私信，不错过任何通知', style: TextStyle(color: Colors.grey[600], fontSize: 14)),
              const SizedBox(height: 28),
              if (_registerMode) ...[
                TextField(
                  controller: _name,
                  maxLength: 20,
                  decoration: const InputDecoration(labelText: '昵称', border: OutlineInputBorder(), counterText: ''),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _email,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(labelText: '邮箱（用于找回密码）', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 12),
              ] else
                TextField(
                  controller: _account,
                  decoration: const InputDecoration(labelText: '识别码 / 自定义ID / 昵称', border: OutlineInputBorder()),
                ),
              const SizedBox(height: 12),
              TextField(
                controller: _password,
                decoration: InputDecoration(labelText: _registerMode ? '密码（至少 6 位）' : '密码', border: const OutlineInputBorder()),
                obscureText: true,
              ),
              if (_registerMode) ...[
                const SizedBox(height: 12),
                TextField(
                  controller: _password2,
                  decoration: const InputDecoration(labelText: '确认密码', border: OutlineInputBorder()),
                  obscureText: true,
                ),
              ],
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(_error!, style: const TextStyle(color: Colors.red)),
              ],
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: FilledButton(
                  onPressed: _loading ? null : _submit,
                  child: _loading
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : Text(_registerMode ? '注册并登录' : '登录'),
                ),
              ),
              const SizedBox(height: 16),
              TextButton(
                onPressed: _loading ? null : () => setState(() { _registerMode = !_registerMode; _error = null; }),
                child: Text(_registerMode ? '已有账号？返回登录' : '没有账号？立即注册'),
              ),
              if (!_registerMode)
                const Padding(
                  padding: EdgeInsets.only(top: 8),
                  child: Text('注册即代表同意社区《用户协议》与《隐私政策》', style: TextStyle(fontSize: 11, color: Colors.grey)),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
