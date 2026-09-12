import 'package:flutter/material.dart';
import 'api.dart';
import 'screens/login.dart';
import 'screens/main_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Api.init();
  runApp(const MakaApp());
}

class MakaApp extends StatelessWidget {
  const MakaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '玛卡之声社区',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF3B82F6)),
        useMaterial3: true,
        appBarTheme: const AppBarTheme(centerTitle: true),
      ),
      home: Api.token != null ? const MainScreen() : const LoginScreen(),
    );
  }
}
