import 'package:flutter_journal_app/shared/widgets/app_lock_wrapper.dart';
import 'package:material_ui/material_ui.dart';

import 'core/services/github_service.dart';
import 'core/services/storage_service.dart';
import 'features/journal/screens/journal_list_screen.dart';
import 'features/quote/screens/quote_list_screen.dart';
import 'features/settings/settings_screen.dart';

void main() {
  runApp(const MyJournalApp());
}

class MyJournalApp extends StatelessWidget {
  const MyJournalApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Nhật ký & Tâm đắc',
      theme: ThemeData(colorSchemeSeed: Colors.teal, useMaterial3: true),
      home: AppLockWrapper(child: const MainNavigationScreen()),
    );
  }
}

class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({super.key});

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  final _storage = StorageService();
  GitHubService? _githubService;
  int _selectedIndex = 0;
  bool _isInitializing = true;

  @override
  void initState() {
    super.initState();
    _initGitHubService();
  }

  Future<void> _initGitHubService() async {
    final config = await _storage.getGitHubConfig();
    final owner = config['owner'];
    final token = config['token'];
    final repo = config['repo'] ?? 'my-journal-data';

    setState(() {
      if (owner != null &&
          owner.isNotEmpty &&
          token != null &&
          token.isNotEmpty) {
        _githubService = GitHubService(owner: owner, repo: repo, token: token);
      } else {
        _githubService = null;
        _selectedIndex = 2; // Chưa có Token -> Tự chuyển sang tab Cài đặt
      }
      _isInitializing = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isInitializing) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final screens = [
      if (_githubService != null)
        JournalListScreen(githubService: _githubService!)
      else
        const Center(
          child: Text('Vui lòng cấu hình GitHub Token ở tab Cài đặt'),
        ),
      if (_githubService != null)
        QuoteListScreen(githubService: _githubService!)
      else
        const Center(
          child: Text('Vui lòng cấu hình GitHub Token ở tab Cài đặt'),
        ),
      SettingsScreen(
        onConfigSaved: () {
          _initGitHubService();
          setState(() => _selectedIndex = 0);
        },
      ),
    ];

    return Scaffold(
      body: screens[_selectedIndex],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (idx) => setState(() => _selectedIndex = idx),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.book), label: 'Nhật ký'),
          NavigationDestination(
            icon: Icon(Icons.format_quote),
            label: 'Tâm đắc',
          ),
          NavigationDestination(icon: Icon(Icons.settings), label: 'Cài đặt'),
        ],
      ),
    );
  }
}
