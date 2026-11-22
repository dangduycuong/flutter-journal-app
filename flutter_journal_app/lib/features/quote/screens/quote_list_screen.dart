import 'package:flutter_journal_app/shared/screens/search_screen.dart';
import 'package:material_ui/material_ui.dart';
import 'package:intl/intl.dart';

import '../../../core/services/github_service.dart';
import '../../../shared/widgets/private_github_image.dart';
import '../models/quote_note.dart';
import 'quote_editor_screen.dart';

class QuoteListScreen extends StatefulWidget {
  final GitHubService githubService;
  const QuoteListScreen({super.key, required this.githubService});

  @override
  State<QuoteListScreen> createState() => _QuoteListScreenState();
}

class _QuoteListScreenState extends State<QuoteListScreen> {
  int _selectedYear = DateTime.now().year;
  List<QuoteNote> _quotes = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _fetchQuotes();
  }

  Future<void> _fetchQuotes() async {
    setState(() => _isLoading = true);
    try {
      final data = await widget.githubService.getQuotesByYear('$_selectedYear');
      setState(() => _quotes = data);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Lỗi tải dữ liệu: $e')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _deleteQuote(QuoteNote quote) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Xóa điều tâm đắc?'),
        content: const Text('Nội dung và ảnh đính kèm sẽ bị xóa khỏi GitHub.'),
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
      await widget.githubService.deleteQuoteNote(quote);
      await _fetchQuotes();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Tâm đắc $_selectedYear'),
        actions: [
          IconButton(
            icon: const Icon(Icons.chevron_left),
            onPressed: () {
              setState(() => _selectedYear--);
              _fetchQuotes();
            },
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right),
            onPressed: () {
              setState(() => _selectedYear++);
              _fetchQuotes();
            },
          ),
          IconButton(icon: const Icon(Icons.refresh), onPressed: _fetchQuotes),
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
          : _quotes.isEmpty
          ? const Center(child: Text('Chưa có điều tâm đắc nào trong năm nay.'))
          : ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: _quotes.length,
              itemBuilder: (context, index) {
                final quote = _quotes[index];
                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: InkWell(
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
                      if (updated == true) _fetchQuotes();
                    },
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                DateFormat('dd/MM/yyyy')
                                    .format(quote.createdAt),
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                              IconButton(
                                icon: const Icon(
                                  Icons.delete_outline,
                                  size: 20,
                                ),
                                onPressed: () => _deleteQuote(quote),
                              ),
                            ],
                          ),
                          Text(
                            '“${quote.content}”',
                            style: const TextStyle(
                              fontSize: 16,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                          if (quote.author != null &&
                              quote.author!.isNotEmpty) ...[
                            const SizedBox(height: 8),
                            Align(
                              alignment: Alignment.centerRight,
                              child: Text(
                                '— ${quote.author}',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Theme.of(context).colorScheme.primary,
                                ),
                              ),
                            ),
                          ],
                          if (quote.imageUrls.isNotEmpty) ...[
                            const SizedBox(height: 10),
                            SizedBox(
                              height: 90,
                              child: ListView.separated(
                                scrollDirection: Axis.horizontal,
                                itemCount: quote.imageUrls.length,
                                separatorBuilder: (_, _) =>
                                    const SizedBox(width: 8),
                                itemBuilder: (_, imgIdx) => PrivateGitHubImage(
                                  owner: widget.githubService.owner,
                                  repo: widget.githubService.repo,
                                  token: widget.githubService.token,
                                  imagePath: quote.imageUrls[imgIdx],
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
                  QuoteEditorScreen(githubService: widget.githubService),
            ),
          );
          if (created == true) _fetchQuotes();
        },
        child: const Icon(Icons.format_quote),
      ),
    );
  }
}
