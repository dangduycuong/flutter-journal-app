import 'package:flutter_journal_app/shared/screens/search_screen.dart';
import 'package:material_ui/material_ui.dart';
import 'package:intl/intl.dart';

import '../../../core/services/github_service.dart';
import '../../../shared/widgets/private_github_image.dart';
import '../models/journal_entry.dart';
import 'journal_editor_screen.dart';

class JournalListScreen extends StatefulWidget {
  final GitHubService githubService;
  const JournalListScreen({super.key, required this.githubService});

  @override
  State<JournalListScreen> createState() => _JournalListScreenState();
}

class _JournalListScreenState extends State<JournalListScreen> {
  DateTime _currentMonth = DateTime.now();
  List<JournalEntry> _entries = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _fetchEntries();
  }

  Future<void> _fetchEntries() async {
    setState(() => _isLoading = true);
    try {
      final monthKey = DateFormat('yyyy-MM').format(_currentMonth);
      final data = await widget.githubService.getJournalsByMonth(
        monthKey,
        onUpdate: (freshData) {
          if (mounted) {
            setState(() => _entries = freshData);
          }
        },
      );
      if (mounted) {
        setState(() => _entries = data);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Lỗi tải dữ liệu: $e')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _deleteEntry(JournalEntry entry) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Xóa nhật ký?'),
        content: const Text('Bài viết và ảnh đính kèm sẽ bị xóa khỏi GitHub.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Hủy'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Xóa'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      setState(() => _isLoading = true);
      await widget.githubService.deleteJournalEntry(entry);
      await _fetchEntries();
    }
  }

  void _changeMonth(int offset) {
    setState(() {
      _currentMonth = DateTime(
        _currentMonth.year,
        _currentMonth.month + offset,
      );
    });
    _fetchEntries();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Nhật ký ${DateFormat('MM/yyyy').format(_currentMonth)}',
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.chevron_left),
            onPressed: () => _changeMonth(-1),
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right),
            onPressed: () => _changeMonth(1),
          ),
          IconButton(icon: const Icon(Icons.refresh), onPressed: _fetchEntries),
          IconButton(
            icon: const Icon(Icons.search),
            tooltip: 'Tìm kiếm',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) =>
                      SearchScreen(githubService: widget.githubService),
                ),
              );
            },
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _entries.isEmpty
          ? const Center(
              child: Text('Chưa có bài nhật ký nào trong tháng này.'),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: _entries.length,
              itemBuilder: (context, index) {
                final entry = _entries[index];
                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: InkWell(
                    onTap: () async {
                      final updated = await Navigator.push<bool>(
                        context,
                        MaterialPageRoute(
                          builder: (_) => JournalEditorScreen(
                            githubService: widget.githubService,
                            existingEntry: entry,
                          ),
                        ),
                      );
                      if (updated == true) _fetchEntries();
                    },
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                DateFormat('dd/MM/yyyy')
                                    .format(entry.entryDate),
                                style: TextStyle(
                                  color: Theme.of(context).colorScheme.primary,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              IconButton(
                                icon: const Icon(
                                  Icons.delete_outline,
                                  size: 20,
                                ),
                                onPressed: () => _deleteEntry(entry),
                              ),
                            ],
                          ),
                          if (entry.title.isNotEmpty) ...[
                            Text(
                              entry.title,
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                          ],
                          Text(
                            entry.content,
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 14, height: 1.4),
                          ),

                          if (entry.imageUrls.isNotEmpty) ...[
                            const SizedBox(height: 8),
                            SizedBox(
                              height: 90,
                              child: ListView.separated(
                                scrollDirection: Axis.horizontal,
                                itemCount: entry.imageUrls.length,
                                separatorBuilder: (_, _) =>
                                    const SizedBox(width: 8),
                                itemBuilder: (_, imgIdx) => PrivateGitHubImage(
                                  owner: widget.githubService.owner,
                                  repo: widget.githubService.repo,
                                  token: widget.githubService.token,
                                  imagePath: entry.imageUrls[imgIdx],
                                  width: 90,
                                  height: 90,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final created = await Navigator.push<bool>(
            context,
            MaterialPageRoute(
              builder: (_) =>
                  JournalEditorScreen(githubService: widget.githubService),
            ),
          );
          if (created == true) _fetchEntries();
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}
