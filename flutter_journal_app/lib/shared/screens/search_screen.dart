import 'dart:async';

import 'package:flutter_journal_app/shared/widgets/%20highlighted_text.dart';
import 'package:material_ui/material_ui.dart';
import 'package:intl/intl.dart';

import '../../core/services/github_service.dart';
import '../../features/journal/models/journal_entry.dart';
import '../../features/journal/screens/journal_editor_screen.dart';
import '../../features/quote/models/quote_note.dart';
import '../../features/quote/screens/quote_editor_screen.dart';

class SearchScreen extends StatefulWidget {
  final GitHubService githubService;
  const SearchScreen({super.key, required this.githubService});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _searchController = TextEditingController();
  Timer? _debounce;
  bool _isSearching = false;
  List<JournalEntry> _journalResults = [];
  List<QuoteNote> _quoteResults = [];
  String _activeQuery = '';

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {
      _performSearch(value);
    });
  }

  Future<void> _performSearch(String keyword) async {
    final cleanQuery = keyword.trim();
    if (cleanQuery.isEmpty) {
      setState(() {
        _activeQuery = '';
        _journalResults = [];
        _quoteResults = [];
        _isSearching = false;
      });
      return;
    }

    setState(() {
      _isSearching = true;
      _activeQuery = cleanQuery;
    });

    try {
      final results = await widget.githubService.searchAll(cleanQuery);
      if (mounted) {
        setState(() {
          _journalResults = List<JournalEntry>.from(results['journals'] ?? []);
          _quoteResults = List<QuoteNote>.from(results['quotes'] ?? []);
        });
      }
    } catch (e, stackTrace) {
      debugPrint('=== LỖI TÌM KIẾM ===');
      debugPrint('Chi tiết lỗi: $e');
      debugPrint('StackTrace: $stackTrace');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Lỗi tìm kiếm: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSearching = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasResults = _journalResults.isNotEmpty || _quoteResults.isNotEmpty;

    return Scaffold(
      appBar: AppBar(
        title: TextField(
          controller: _searchController,
          autofocus: true,
          onChanged: _onSearchChanged,
          onSubmitted: _performSearch,
          decoration: InputDecoration(
            hintText: 'Tìm nhật ký, tâm đắc (có hoặc không dấu)...',
            border: InputBorder.none,
            suffixIcon: _searchController.text.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.clear),
                    onPressed: () {
                      _searchController.clear();
                      _performSearch('');
                    },
                  )
                : null,
          ),
        ),
      ),
      body: _isSearching
          ? const Center(child: CircularProgressIndicator())
          : _activeQuery.isEmpty
          ? const Center(
              child: Text(
                'Nhập từ khóa để tìm kiếm toàn bộ bài viết',
                style: TextStyle(color: Colors.grey),
              ),
            )
          : !hasResults
          ? Center(
              child: Text(
                'Không tìm thấy kết quả nào cho "$_activeQuery"',
                style: const TextStyle(color: Colors.grey),
              ),
            )
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                if (_journalResults.isNotEmpty) ...[
                  Text(
                    'Nhật ký (${_journalResults.length})',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  ..._journalResults.map(
                    (entry) => Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: ListTile(
                        contentPadding: const EdgeInsets.all(12),
                        title: HighlightedText(
                          text: entry.title.isEmpty
                              ? 'Không tiêu đề'
                              : entry.title,
                          query: _activeQuery,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                          maxLines: 1,
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 4),
                            Text(
                              DateFormat('dd/MM/yyyy HH:mm')
                                  .format(entry.entryDate),
                              style: TextStyle(
                                fontSize: 12,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                            ),
                            const SizedBox(height: 6),
                            HighlightedText(
                              text: entry.content,
                              query: _activeQuery,
                              style: const TextStyle(fontSize: 14),
                              maxLines: 3,
                            ),
                          ],
                        ),
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
                          if (updated == true) {
                            _performSearch(_activeQuery);
                          }
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
                if (_quoteResults.isNotEmpty) ...[
                  Text(
                    'Tâm đắc (${_quoteResults.length})',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  ..._quoteResults.map(
                    (quote) => Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: ListTile(
                        contentPadding: const EdgeInsets.all(12),
                        title: HighlightedText(
                          text: quote.content,
                          query: _activeQuery,
                          style: const TextStyle(
                            fontSize: 15,
                            fontStyle: FontStyle.italic,
                          ),
                          maxLines: 4,
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (quote.author != null &&
                                quote.author!.isNotEmpty) ...[
                              const SizedBox(height: 6),
                              HighlightedText(
                                text: '— ${quote.author!}',
                                query: _activeQuery,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w500,
                                  fontSize: 13,
                                ),
                                maxLines: 1,
                              ),
                            ],
                            const SizedBox(height: 4),
                            Text(
                              DateFormat('dd/MM/yyyy').format(quote.createdAt),
                              style: const TextStyle(
                                fontSize: 12,
                                color: Colors.grey,
                              ),
                            ),
                          ],
                        ),
                        onTap: () async {
                          final updated = await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => QuoteEditorScreen(
                                githubService: widget.githubService,
                                existingQuote: quote,
                              ),
                            ),
                          );
                          if (updated == true) {
                            _performSearch(_activeQuery);
                          }
                        },
                      ),
                    ),
                  ),
                ],
              ],
            ),
    );
  }
}
