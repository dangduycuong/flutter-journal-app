import 'dart:io';

import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/services/github_service.dart';
import '../../../shared/widgets/private_github_image.dart';
import '../models/journal_entry.dart';

class JournalEditorScreen extends StatefulWidget {
  final GitHubService githubService;
  final JournalEntry? existingEntry;

  const JournalEditorScreen({
    super.key,
    required this.githubService,
    this.existingEntry,
  });

  @override
  State<JournalEditorScreen> createState() => _JournalEditorScreenState();
}

class _JournalEditorScreenState extends State<JournalEditorScreen> {
  final _titleController = TextEditingController();
  final _contentController = TextEditingController();
  late DateTime _selectedEntryDate;
  List<String> _existingImageUrls = [];
  final List<File> _newImageFiles = [];
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    if (widget.existingEntry != null) {
      final e = widget.existingEntry!;
      _titleController.text = e.title;
      _contentController.text = e.content;
      _selectedEntryDate = e.entryDate;
      _existingImageUrls = List.from(e.imageUrls);
    } else {
      _selectedEntryDate = DateTime.now();
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
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

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedEntryDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() => _selectedEntryDate = picked);
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

  Future<void> _saveEntry() async {
    if (_contentController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vui lòng nhập nội dung nhật ký')),
      );
      return;
    }

    setState(() => _isSaving = true);
    try {
      final now = DateTime.now();
      final entryId = widget.existingEntry?.id ?? const Uuid().v4();

      final List<String> finalImageUrls = List.from(_existingImageUrls);
      for (final file in _newImageFiles) {
        final uploadedPath = await widget.githubService.uploadImage(
          file,
          entryId,
        );
        finalImageUrls.add(uploadedPath);
      }

      final entry = JournalEntry(
        id: entryId,
        title: _titleController.text.trim(),
        content: _contentController.text.trim(),
        entryDate: _selectedEntryDate,
        createdAt: widget.existingEntry?.createdAt ?? now,
        updatedAt: now,
        imageUrls: finalImageUrls,
      );

      await widget.githubService.saveJournalEntry(
        entry,
        oldEntry: widget.existingEntry,
      );

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
    final isEditing = widget.existingEntry != null;
    return Scaffold(
      appBar: AppBar(
        title: Text(isEditing ? 'Sửa nhật ký' : 'Viết nhật ký mới'),
        actions: [
          IconButton(
            onPressed: _isSaving ? null : _pasteFromClipboard,
            tooltip: 'Dán văn bản',
            icon: const Icon(Icons.content_paste),
          ),
          IconButton(
            onPressed: _isSaving ? null : _saveEntry,
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
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.calendar_today),
              title: const Text('Ngày ghi nhật ký'),
              subtitle: Text(
                DateFormat('dd/MM/yyyy').format(_selectedEntryDate),
              ),
              trailing: TextButton(
                onPressed: _pickDate,
                child: const Text('Đổi ngày'),
              ),
            ),
            const Divider(),
            TextField(
              controller: _titleController,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                hintText: 'Tiêu đề (tùy chọn)',
                border: InputBorder.none,
              ),
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            TextField(
              controller: _contentController,
              keyboardType: TextInputType.multiline,
              maxLines: null,
              minLines: 10,
              decoration: const InputDecoration(
                hintText: 'Hôm nay của bạn thế nào...',
                border: InputBorder.none,
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
              label: const Text('Thêm ảnh đính kèm'),
            ),
          ],
        ),
      ),
    );
  }
}
