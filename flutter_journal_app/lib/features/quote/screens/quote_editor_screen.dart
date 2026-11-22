import 'dart:io';

import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';
import 'package:uuid/uuid.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/services/github_service.dart';
import '../../../shared/widgets/private_github_image.dart';
import '../models/quote_note.dart';

class QuoteEditorScreen extends StatefulWidget {
  final GitHubService githubService;
  final QuoteNote? existingQuote;

  const QuoteEditorScreen({
    super.key,
    required this.githubService,
    this.existingQuote,
  });

  @override
  State<QuoteEditorScreen> createState() => _QuoteEditorScreenState();
}

class _QuoteEditorScreenState extends State<QuoteEditorScreen> {
  final _contentController = TextEditingController();
  final _authorController = TextEditingController();
  List<String> _existingImageUrls = [];
  final List<File> _newImageFiles = [];
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    if (widget.existingQuote != null) {
      final q = widget.existingQuote!;
      _contentController.text = q.content;
      _authorController.text = q.author ?? '';
      _existingImageUrls = List.from(q.imageUrls);
    }
  }

  @override
  void dispose() {
    _contentController.dispose();
    _authorController.dispose();
    super.dispose();
  }

  Future<void> _pasteFromClipboard() async {
    // Ẩn bàn phím tạm thời để iOS không chặn bộ đệm khi dán văn bản lớn
    FocusScope.of(context).unfocus();
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    if (data?.text != null && data!.text!.isNotEmpty) {
      final currentText = _contentController.text;
      final newText = currentText.isEmpty
          ? data.text!
          : '$currentText\n${data.text!}';
      setState(() {
        _contentController.text = newText;
      });
    } else {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Bộ nhớ tạm trống hoặc chứa định dạng không phải văn bản',
          ),
        ),
      );
    }
  }

  Future<void> _pickImages() async {
    final picker = ImagePicker();
    final pickedFiles = await picker.pickMultiImage(
      imageQuality: 75,
      maxWidth: 1200,
    );
    if (pickedFiles.isNotEmpty) {
      setState(() {
        _newImageFiles.addAll(pickedFiles.map((e) => File(e.path)));
      });
    }
  }

  Future<void> _saveQuote() async {
    if (_contentController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vui lòng nhập nội dung tâm đắc')),
      );
      return;
    }

    setState(() => _isSaving = true);
    try {
      final quoteId = widget.existingQuote?.id ?? const Uuid().v4();

      final List<String> finalImageUrls = List.from(_existingImageUrls);
      for (final file in _newImageFiles) {
        final uploadedPath = await widget.githubService.uploadImage(
          file,
          quoteId,
        );
        finalImageUrls.add(uploadedPath);
      }

      final quote = QuoteNote(
        id: quoteId,
        content: _contentController.text.trim(),
        author: _authorController.text.trim().isEmpty
            ? null
            : _authorController.text.trim(),
        createdAt: widget.existingQuote?.createdAt ?? DateTime.now(),
        imageUrls: finalImageUrls,
      );

      await widget.githubService.saveQuoteNote(quote);

      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Lỗi khi lưu: $e')));
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.existingQuote != null;
    return Scaffold(
      appBar: AppBar(
        title: Text(isEditing ? 'Sửa điều tâm đắc' : 'Lưu điều tâm đắc'),
        actions: [
          IconButton(
            onPressed: _isSaving ? null : _pasteFromClipboard,
            tooltip: 'Dán văn bản',
            icon: const Icon(Icons.content_paste),
          ),
          IconButton(
            onPressed: _isSaving ? null : _saveQuote,
            icon: _isSaving
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.check),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _contentController,
              keyboardType: TextInputType.multiline,
              maxLines: null,
              minLines: 10,
              decoration: const InputDecoration(
                hintText: 'Viết câu nói hay hoặc điều bạn tâm đắc...',
                border: InputBorder.none,
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _authorController,
              decoration: InputDecoration(
                labelText: 'Tác giả / Nguồn (tùy chọn)',
                border: const OutlineInputBorder(),
                suffixIcon: ValueListenableBuilder<TextEditingValue>(
                  valueListenable: _authorController,
                  builder: (context, value, child) {
                    if (value.text.isEmpty) return const SizedBox.shrink();
                    return IconButton(
                      icon: const Icon(Icons.close, size: 20),
                      tooltip: 'Xóa tác giả',
                      onPressed: () => _authorController.clear(),
                    );
                  },
                ),
              ),
            ),

            const SizedBox(height: 16),
            if (_existingImageUrls.isNotEmpty) ...[
              const Text(
                'Ảnh đã lưu:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _existingImageUrls.map((path) {
                  return Stack(
                    children: [
                      PrivateGitHubImage(
                        owner: widget.githubService.owner,
                        repo: widget.githubService.repo,
                        token: widget.githubService.token,
                        imagePath: path,
                        width: 100,
                        height: 100,
                      ),
                      Positioned(
                        right: 0,
                        top: 0,
                        child: GestureDetector(
                          onTap: () =>
                              setState(() => _existingImageUrls.remove(path)),
                          child: const CircleAvatar(
                            radius: 12,
                            backgroundColor: Colors.black54,
                            child: Icon(
                              Icons.close,
                              size: 14,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ],
                  );
                }).toList(),
              ),
              const SizedBox(height: 12),
            ],
            if (_newImageFiles.isNotEmpty) ...[
              const Text(
                'Ảnh mới thêm:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _newImageFiles.map((file) {
                  return Stack(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.file(
                          file,
                          width: 100,
                          height: 100,
                          fit: BoxFit.cover,
                        ),
                      ),
                      Positioned(
                        right: 0,
                        top: 0,
                        child: GestureDetector(
                          onTap: () =>
                              setState(() => _newImageFiles.remove(file)),
                          child: const CircleAvatar(
                            radius: 12,
                            backgroundColor: Colors.black54,
                            child: Icon(
                              Icons.close,
                              size: 14,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ],
                  );
                }).toList(),
              ),
            ],
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: _isSaving ? null : _pickImages,
              icon: const Icon(Icons.photo_library),
              label: const Text('Thêm ảnh trang sách / minh họa'),
            ),
          ],
        ),
      ),
    );
  }
}
