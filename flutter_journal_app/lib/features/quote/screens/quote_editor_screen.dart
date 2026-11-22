import 'dart:io';

import 'package:material_ui/material_ui.dart';
import 'package:image_picker/image_picker.dart';
import 'package:uuid/uuid.dart';

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
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: _contentController,
            maxLines: null,
            minLines: 6,
            decoration: const InputDecoration(
              hintText: 'Viết câu nói hay hoặc điều bạn tâm đắc...',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _authorController,
            decoration: const InputDecoration(
              labelText: 'Tác giả / Nguồn sách (tùy chọn)',
              border: OutlineInputBorder(),
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
    );
  }
}
