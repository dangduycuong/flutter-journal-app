import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_journal_app/core/utils/vietnamese_helper.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';

import '../../features/journal/models/journal_entry.dart';
import '../../features/quote/models/quote_note.dart';

class GitHubService {
  final String owner;
  final String repo;
  final String token;

  // Tách riêng host để không bị trình duyệt rút gọn khi copy

  static const String _apiHost =
      'api'
      '.github.com';

  GitHubService({
    required String owner,
    required String repo,
    required String token,
  }) : owner = owner.trim(),
       repo = repo.trim(),
       token = token.trim();

  Map<String, String> get _headers => {
    'Authorization': 'Bearer $token',
    'Accept': 'application/json',
    'User-Agent': 'Flutter-Journal-App',
  };

  // Hàm tạo Uri chuẩn bằng Uri.https (an toàn tuyệt đối, không sợ lỗi chuỗi)
  Uri _buildContentUri(String path) {
    return Uri.https(_apiHost, '/repos/$owner/$repo/contents/$path');
  }

  // ==========================================
  // PHẦN 1: XỬ LÝ ẢNH (UPLOAD & XÓA)
  // ==========================================

  Future<String> uploadImage(File imageFile, String entryId) async {
    final monthFolder = DateFormat('yyyy-MM').format(DateTime.now());
    final fileName = '${entryId}_${DateTime.now().millisecondsSinceEpoch}.jpg';
    final path = 'images/$monthFolder/$fileName';

    final bytes = await imageFile.readAsBytes();
    final base64Image = base64Encode(bytes);

    final url = _buildContentUri(path);

    debugPrint('=== BẮT ĐẦU UPLOAD ẢNH ===');
    debugPrint('URL gọi: $url');
    debugPrint(
      'Dung lượng ảnh: ${(bytes.length / 1024).toStringAsFixed(1)} KB',
    );

    final response = await http.put(
      url,
      headers: _headers,
      body: jsonEncode({
        'message': 'Upload image $fileName',
        'content': base64Image,
      }),
    );

    debugPrint('Mã phản hồi HTTP: ${response.statusCode}');
    debugPrint('===========================');

    if (response.statusCode == 201 || response.statusCode == 200) {
      return path;
    } else {
      throw Exception(
        'Lỗi upload ảnh (${response.statusCode}): ${_extractErrorMessage(response.body)}',
      );
    }
  }

  Future<void> deleteFile(String path) async {
    final url = _buildContentUri(path);
    final getRes = await http.get(url, headers: _headers);
    if (getRes.statusCode == 200) {
      final sha = jsonDecode(getRes.body)['sha'];
      await http.delete(
        url,
        headers: _headers,
        body: jsonEncode({'message': 'Delete file $path', 'sha': sha}),
      );
    }
  }

  // ==========================================
  // PHẦN 2: NHẬT KÝ (ĐỌC, THÊM, SỬA, XÓA)
  // ==========================================

  Future<List<JournalEntry>> getJournalsByMonth(String monthKey) async {
    final path = 'data/journals/$monthKey.json';
    final result = await _fetchJsonList(path);
    final List<dynamic> list = result['data'];
    return list.map((e) => JournalEntry.fromJson(e)).toList();
  }

  Future<void> saveJournalEntry(
    JournalEntry entry, {
    JournalEntry? oldEntry,
  }) async {
    final newMonthKey = DateFormat('yyyy-MM').format(entry.entryDate);

    if (oldEntry != null) {
      final oldMonthKey = DateFormat('yyyy-MM').format(oldEntry.entryDate);
      if (oldMonthKey != newMonthKey) {
        await deleteJournalEntry(oldEntry, deleteImages: false);
      }
    }

    final path = 'data/journals/$newMonthKey.json';
    final result = await _fetchJsonList(path);
    final List<JournalEntry> entries = (result['data'] as List)
        .map((e) => JournalEntry.fromJson(e))
        .toList();
    final String? sha = result['sha'];

    final index = entries.indexWhere((e) => e.id == entry.id);
    if (index >= 0) {
      entries[index] = entry;
    } else {
      entries.add(entry);
    }

    entries.sort((a, b) => b.entryDate.compareTo(a.entryDate));
    await _saveJsonList(
      path: path,
      data: entries.map((e) => e.toJson()).toList(),
      sha: sha,
      commitMessage: 'Save journal ${entry.id}',
    );
  }

  Future<void> deleteJournalEntry(
    JournalEntry entry, {
    bool deleteImages = true,
  }) async {
    final monthKey = DateFormat('yyyy-MM').format(entry.entryDate);
    final path = 'data/journals/$monthKey.json';
    final result = await _fetchJsonList(path);
    final String? sha = result['sha'];
    if (sha == null) return;

    final List<JournalEntry> entries = (result['data'] as List)
        .map((e) => JournalEntry.fromJson(e))
        .toList();
    entries.removeWhere((e) => e.id == entry.id);

    await _saveJsonList(
      path: path,
      data: entries.map((e) => e.toJson()).toList(),
      sha: sha,
      commitMessage: 'Delete journal ${entry.id}',
    );

    if (deleteImages) {
      for (final imgPath in entry.imageUrls) {
        await deleteFile(imgPath);
      }
    }
  }

  // ==========================================
  // PHẦN 3: TÂM ĐẮC / CÂU NÓI HAY (ĐỌC, THÊM, SỬA, XÓA)
  // ==========================================

  Future<List<QuoteNote>> getQuotesByYear(String yearKey) async {
    final path = 'data/quotes/$yearKey.json';
    final result = await _fetchJsonList(path);
    final List<dynamic> list = result['data'];
    return list.map((e) => QuoteNote.fromJson(e)).toList();
  }

  Future<void> saveQuoteNote(QuoteNote quote) async {
    final yearKey = DateFormat('yyyy').format(quote.createdAt);
    final path = 'data/quotes/$yearKey.json';
    final result = await _fetchJsonList(path);
    final List<QuoteNote> quotes = (result['data'] as List)
        .map((e) => QuoteNote.fromJson(e))
        .toList();
    final String? sha = result['sha'];

    final index = quotes.indexWhere((e) => e.id == quote.id);
    if (index >= 0) {
      quotes[index] = quote;
    } else {
      quotes.add(quote);
    }

    quotes.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    await _saveJsonList(
      path: path,
      data: quotes.map((e) => e.toJson()).toList(),
      sha: sha,
      commitMessage: 'Save quote ${quote.id}',
    );
  }

  Future<void> deleteQuoteNote(
    QuoteNote quote, {
    bool deleteImages = true,
  }) async {
    final yearKey = DateFormat('yyyy').format(quote.createdAt);
    final path = 'data/quotes/$yearKey.json';
    final result = await _fetchJsonList(path);
    final String? sha = result['sha'];
    if (sha == null) return;

    final List<QuoteNote> quotes = (result['data'] as List)
        .map((e) => QuoteNote.fromJson(e))
        .toList();
    quotes.removeWhere((e) => e.id == quote.id);

    await _saveJsonList(
      path: path,
      data: quotes.map((e) => e.toJson()).toList(),
      sha: sha,
      commitMessage: 'Delete quote ${quote.id}',
    );

    if (deleteImages) {
      for (final imgPath in quote.imageUrls) {
        await deleteFile(imgPath);
      }
    }
  }

  // ==========================================
  // HÀM HỖ TRỢ ĐỌC/GHI JSON CHUNG
  // ==========================================

  Future<Map<String, dynamic>> _fetchJsonList(String path) async {
    final url = _buildContentUri(path);
    final res = await http.get(url, headers: _headers);

    if (res.statusCode == 200) {
      final body = jsonDecode(res.body);
      final decoded = utf8.decode(
        base64Decode(body['content'].replaceAll('\n', '')),
      );
      return {'data': jsonDecode(decoded) as List<dynamic>, 'sha': body['sha']};
    } else if (res.statusCode == 404) {
      return {'data': <dynamic>[], 'sha': null};
    } else {
      throw Exception(
        'Lỗi đọc GitHub (${res.statusCode}): ${_extractErrorMessage(res.body)}',
      );
    }
  }

  Future<void> _saveJsonList({
    required String path,
    required List<dynamic> data,
    required String? sha,
    required String commitMessage,
  }) async {
    final url = _buildContentUri(path);
    final jsonString = const JsonEncoder.withIndent('  ').convert(data);
    final base64Content = base64Encode(utf8.encode(jsonString));

    final body = <String, dynamic>{
      'message': commitMessage,
      'content': base64Content,
    };
    if (sha != null) body['sha'] = sha;

    final res = await http.put(url, headers: _headers, body: jsonEncode(body));
    if (res.statusCode != 200 && res.statusCode != 201) {
      throw Exception(
        'Lỗi ghi GitHub (${res.statusCode}): ${_extractErrorMessage(res.body)}',
      );
    }
  }

  String _extractErrorMessage(String responseBody) {
    try {
      final decoded = jsonDecode(responseBody);
      return decoded['message'] ?? responseBody;
    } catch (_) {
      return responseBody;
    }
  }
  // ==========================================
  // PHẦN 4: TÌM KIẾM TỪ KHÓA TOÀN BỘ DỮ LIỆU
  // ==========================================

  // Lấy danh sách tên file trong một thư mục trên GitHub
  Future<List<String>> _listFilesInDirectory(String dirPath) async {
    final url = _buildContentUri(dirPath);
    final res = await http.get(url, headers: _headers);
    if (res.statusCode == 200) {
      final List<dynamic> items = jsonDecode(res.body);
      return items
          .where(
            (item) =>
                item['type'] == 'file' &&
                (item['name'] as String).endsWith('.json'),
          )
          .map((item) => item['path'] as String)
          .toList();
    }
    return [];
  }

  // Tìm kiếm từ khóa không dấu / có dấu trong cả Nhật ký và Tâm đắc
  Future<Map<String, List<dynamic>>> searchAll(String keyword) async {
    final query = keyword.trim();
    if (query.isEmpty) {
      return {'journals': <JournalEntry>[], 'quotes': <QuoteNote>[]};
    }

    final List<JournalEntry> matchedJournals = [];
    final List<QuoteNote> matchedQuotes = [];

    // 1. Quét toàn bộ file trong data/journals
    final journalFiles = await _listFilesInDirectory('data/journals');
    for (final filePath in journalFiles) {
      final result = await _fetchJsonList(filePath);
      final entries = (result['data'] as List).map(
        (e) => JournalEntry.fromJson(e),
      );
      matchedJournals.addAll(
        entries.where(
          (e) =>
              VietnameseHelper.matches(e.title, query) ||
              VietnameseHelper.matches(e.content, query),
        ),
      );
    }

    // 2. Quét toàn bộ file trong data/quotes
    final quoteFiles = await _listFilesInDirectory('data/quotes');
    for (final filePath in quoteFiles) {
      final result = await _fetchJsonList(filePath);
      final quotes = (result['data'] as List).map((e) => QuoteNote.fromJson(e));
      matchedQuotes.addAll(
        quotes.where(
          (q) =>
              VietnameseHelper.matches(q.content, query) ||
              (q.author != null && VietnameseHelper.matches(q.author!, query)),
        ),
      );
    }

    // Sắp xếp kết quả mới nhất lên đầu
    matchedJournals.sort((a, b) => b.entryDate.compareTo(a.entryDate));
    matchedQuotes.sort((a, b) => b.createdAt.compareTo(a.createdAt));

    return {'journals': matchedJournals, 'quotes': matchedQuotes};
  }
}
