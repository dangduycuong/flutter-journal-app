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
  bool _isSearching = false;
  bool _hasSearched = false;
  List<JournalEntry> _journalResults = [];
  List<QuoteNote> _quoteResults = [];

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _performSearch() async {
    final keyword = _searchController.text.trim();
    if (keyword.isEmpty) return;

    FocusScope.of(context).unfocus(); // Ẩn bàn phím
    setState(() {
      _isSearching = true;
      _hasSearched = true;
    });

    try {
      final results = await widget.githubService.searchAll(keyword);
      setState(() {
        _journalResults = results['journals'] as List<JournalEntry>;
        _quoteResults = results['quotes'] as List<QuoteNote>;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Lỗi tìm kiếm: $e')));
      }
    } finally {
      if (mounted) setState(() => _isSearching = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final totalFound = _journalResults.length + _quoteResults.length;

    return Scaffold(
      appBar: AppBar(
        title: TextField(
          controller: _searchController,
          autofocus: true,
          textInputAction: TextInputAction.search,
          onSubmitted: (_) => _performSearch(),
          decoration: InputDecoration(
            hintText: 'Nhập từ khóa nhật ký, câu nói...',
            border: InputBorder.none,
            suffixIcon: _searchController.text.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.clear),
                    onPressed: () {
                      _searchController.clear();
                      setState(() {
                        _journalResults = [];
                        _quoteResults = [];
                        _hasSearched = false;
                      });
                    },
                  )
                : null,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: _isSearching ? null : _performSearch,
          ),
        ],
      ),
      body: _isSearching
          ? const Center(child: CircularProgressIndicator())
          : !_hasSearched
          ? const Center(child: Text('Nhập từ khóa và bấm tìm kiếm'))
          : totalFound == 0
          ? const Center(child: Text('Không tìm thấy kết quả nào phù hợp.'))
          : ListView(
              padding: const EdgeInsets.all(12),
              children: [
                if (_journalResults.isNotEmpty) ...[
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Text(
                      'Nhật ký (${_journalResults.length})',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  ..._journalResults.map(
                    (entry) => Card(
                      child: ListTile(
                        leading: const Icon(Icons.book, color: Colors.teal),
                        title: Text(
                          entry.title.isNotEmpty
                              ? entry.title
                              : DateFormat('dd/MM/yyyy')
                                    .format(entry.entryDate),
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Text(
                          '${DateFormat('dd/MM/yyyy').format(entry.entryDate)} • ${entry.content}',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
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
                          if (updated == true) _performSearch();
                        },
                      ),
                    ),
                  ),
                ],
                if (_quoteResults.isNotEmpty) ...[
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Text(
                      'Điều tâm đắc (${_quoteResults.length})',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  ..._quoteResults.map(
                    (quote) => Card(
                      child: ListTile(
                        leading: const Icon(
                          Icons.format_quote,
                          color: Colors.amber,
                        ),
                        title: Text(
                          '“${quote.content}”',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontStyle: FontStyle.italic),
                        ),
                        subtitle: Text(
                          quote.author != null && quote.author!.isNotEmpty
                              ? '— ${quote.author}'
                              : DateFormat('dd/MM/yyyy')
                                    .format(quote.createdAt),
                        ),
                        onTap: () async {
                          final updated = await Navigator.push<bool>(
                            context,
                            MaterialPageRoute(
                              builder: (_) => QuoteEditorScreen(
                                githubService: widget.githubService,
                                existingQuote: quote,
                              ),
                            ),
                          );
                          if (updated == true) _performSearch();
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
