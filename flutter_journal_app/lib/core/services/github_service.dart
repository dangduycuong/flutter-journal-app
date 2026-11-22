import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_journal_app/core/utils/vietnamese_helper.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';

import '../../features/journal/models/journal_entry.dart';
import '../../features/quote/models/quote_note.dart';

class GitHubService {
  final String owner;
  final String repo;
  final String token;

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

  Uri _buildContentUri(String path) {
    return Uri.https(_apiHost, '/repos/$owner/$repo/contents/$path');
  }

  // ==========================================
  // QUẢN LÝ BỘ NHỚ ĐỆM OFFLINE (CACHE)
  // ==========================================

  Future<File> _getCacheFile(String githubPath) async {
    final dir = await getApplicationDocumentsDirectory();
    final safeFileName = githubPath.replaceAll('/', '_');
    return File('${dir.path}/cache_$safeFileName');
  }

  Future<List<dynamic>?> _readCache(String githubPath) async {
    try {
      final file = await _getCacheFile(githubPath);
      if (await file.exists()) {
        final content = await file.readAsString();
        return jsonDecode(content) as List<dynamic>;
      }
    } catch (e) {
      debugPrint('Lỗi đọc cache ($githubPath): $e');
    }
    return null;
  }

  Future<void> _writeCache(String githubPath, List<dynamic> data) async {
    try {
      final file = await _getCacheFile(githubPath);
      await file.writeAsString(jsonEncode(data));
    } catch (e) {
      debugPrint('Lỗi ghi cache ($githubPath): $e');
    }
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

    final response = await http.put(
      url,
      headers: _headers,
      body: jsonEncode({
        'message': 'Upload image $fileName',
        'content': base64Image,
      }),
    );

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
  // PHẦN 2: NHẬT KÝ (ĐỌC CACHE + ĐỒNG BỘ NGẦM)
  // ==========================================

  Future<List<JournalEntry>> getJournalsByMonth(
    String monthKey, {
    void Function(List<JournalEntry> freshData)? onUpdate,
  }) async {
    final path = 'data/journals/$monthKey.json';
    final cachedRaw = await _readCache(path);

    if (cachedRaw != null) {
      // Có cache -> tải ngầm bản mới từ GitHub và báo qua callback onUpdate
      _fetchJsonList(path)
          .then((result) async {
            final freshRaw = result['data'] as List<dynamic>;
            await _writeCache(path, freshRaw);
            if (onUpdate != null) {
              onUpdate(freshRaw.map((e) => JournalEntry.fromJson(e)).toList());
            }
          })
          .catchError((e) {
            debugPrint('Đang offline hoặc lỗi đồng bộ ngầm nhật ký: $e');
          });

      return cachedRaw.map((e) => JournalEntry.fromJson(e)).toList();
    }

    // Lần đầu chưa có cache -> tải trực tiếp từ mạng và lưu cache
    final result = await _fetchJsonList(path);
    final freshRaw = result['data'] as List<dynamic>;
    await _writeCache(path, freshRaw);
    return freshRaw.map((e) => JournalEntry.fromJson(e)).toList();
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
    final jsonList = entries.map((e) => e.toJson()).toList();

    await _saveJsonList(
      path: path,
      data: jsonList,
      sha: sha,
      commitMessage: 'Save journal ${entry.id}',
    );
    await _writeCache(path, jsonList); // Cập nhật ngay cache cục bộ
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
    final jsonList = entries.map((e) => e.toJson()).toList();

    await _saveJsonList(
      path: path,
      data: jsonList,
      sha: sha,
      commitMessage: 'Delete journal ${entry.id}',
    );
    await _writeCache(path, jsonList); // Cập nhật ngay cache cục bộ

    if (deleteImages) {
      for (final imgPath in entry.imageUrls) {
        await deleteFile(imgPath);
      }
    }
  }

  // ==========================================
  // PHẦN 3: TÂM ĐẮC (ĐỌC CACHE + ĐỒNG BỘ NGẦM)
  // ==========================================

  Future<List<QuoteNote>> getQuotesByYear(
    String yearKey, {
    void Function(List<QuoteNote> freshData)? onUpdate,
  }) async {
    final path = 'data/quotes/$yearKey.json';
    final cachedRaw = await _readCache(path);

    if (cachedRaw != null) {
      _fetchJsonList(path)
          .then((result) async {
            final freshRaw = result['data'] as List<dynamic>;
            await _writeCache(path, freshRaw);
            if (onUpdate != null) {
              onUpdate(freshRaw.map((e) => QuoteNote.fromJson(e)).toList());
            }
          })
          .catchError((e) {
            debugPrint('Đang offline hoặc lỗi đồng bộ ngầm tâm đắc: $e');
          });

      return cachedRaw.map((e) => QuoteNote.fromJson(e)).toList();
    }

    final result = await _fetchJsonList(path);
    final freshRaw = result['data'] as List<dynamic>;
    await _writeCache(path, freshRaw);
    return freshRaw.map((e) => QuoteNote.fromJson(e)).toList();
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
    final jsonList = quotes.map((e) => e.toJson()).toList();

    await _saveJsonList(
      path: path,
      data: jsonList,
      sha: sha,
      commitMessage: 'Save quote ${quote.id}',
    );
    await _writeCache(path, jsonList); // Cập nhật ngay cache cục bộ
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
    final jsonList = quotes.map((e) => e.toJson()).toList();

    await _saveJsonList(
      path: path,
      data: jsonList,
      sha: sha,
      commitMessage: 'Delete quote ${quote.id}',
    );
    await _writeCache(path, jsonList); // Cập nhật ngay cache cục bộ

    if (deleteImages) {
      for (final imgPath in quote.imageUrls) {
        await deleteFile(imgPath);
      }
    }
  }

  // ==========================================
  // PHẦN 4: TÌM KIẾM TỪ KHÓA (HỖ TRỢ OFFLINE CACHE)
  // ==========================================

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

  Future<Map<String, List>> searchAll(String keyword) async {
    final query = keyword.trim();
    if (query.isEmpty) {
      return {'journals': [], 'quotes': []};
    }
    final List matchedJournals = [];
    final List matchedQuotes = [];
    try {
      // Ưu tiên tìm trên GitHub và làm mới cache
      final journalFiles = await _listFilesInDirectory('data/journals');
      for (final filePath in journalFiles) {
        final result = await _fetchJsonList(filePath);
        final rawList = result['data'] as List;
        await _writeCache(filePath, rawList);
        final entries = rawList.map((e) => JournalEntry.fromJson(e));
        matchedJournals.addAll(
          entries.where(
            (e) =>
                VietnameseHelper.matches(e.title, query) ||
                VietnameseHelper.matches(e.content, query),
          ),
        );
      }
      final quoteFiles = await _listFilesInDirectory('data/quotes');
      for (final filePath in quoteFiles) {
        final result = await _fetchJsonList(filePath);
        final rawList = result['data'] as List;
        await _writeCache(filePath, rawList);
        final quotes = rawList.map((e) => QuoteNote.fromJson(e));
        matchedQuotes.addAll(
          quotes.where(
            (q) =>
                VietnameseHelper.matches(q.content, query) ||
                (q.author != null &&
                    VietnameseHelper.matches(q.author!, query)),
          ),
        );
      }
    } catch (e) {
      // Nếu mất mạng -> tự động tìm kiếm trong các file Cache đã lưu trên máy
      debugPrint('Đang offline, chuyển sang tìm kiếm trong Cache: $e');
      final dir = await getApplicationDocumentsDirectory();
      final cacheFiles = dir.listSync().whereType();
      for (final file in cacheFiles) {
        final name = file.path.split('/').last;
        if (name.startsWith('cache_data_journals')) {
          final rawList = jsonDecode(await file.readAsString()) as List;
          final entries = rawList.map((e) => JournalEntry.fromJson(e));
          matchedJournals.addAll(
            entries.where(
              (e) =>
                  VietnameseHelper.matches(e.title, query) ||
                  VietnameseHelper.matches(e.content, query),
            ),
          );
        } else if (name.startsWith('cache_data_quotes')) {
          final rawList = jsonDecode(await file.readAsString()) as List;
          final quotes = rawList.map((e) => QuoteNote.fromJson(e));
          matchedQuotes.addAll(
            quotes.where(
              (q) =>
                  VietnameseHelper.matches(q.content, query) ||
                  (q.author != null &&
                      VietnameseHelper.matches(q.author!, query)),
            ),
          );
        }
      }
    }
    matchedJournals.sort((a, b) => b.entryDate.compareTo(a.entryDate));
    matchedQuotes.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return {'journals': matchedJournals, 'quotes': matchedQuotes};
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
      return {'data': jsonDecode(decoded) as List, 'sha': body['sha']};
    } else if (res.statusCode == 404) {
      return {'data': [], 'sha': null};
    } else {
      throw Exception(
        'Lỗi đọc GitHub (${res.statusCode}): ${_extractErrorMessage(res.body)}',
      );
    }
  }

  Future _saveJsonList({
    required String path,
    required List data,
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
}
