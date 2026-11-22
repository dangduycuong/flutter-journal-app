import 'dart:io';

import 'package:material_ui/material_ui.dart';
import 'package:path_provider/path_provider.dart';

class FullScreenImageViewer extends StatefulWidget {
  final String owner;
  final String repo;
  final String token;
  final List<String> imagePaths;
  final int initialIndex;

  const FullScreenImageViewer({
    super.key,
    required this.owner,
    required this.repo,
    required this.token,
    required this.imagePaths,
    this.initialIndex = 0,
  });

  @override
  State<FullScreenImageViewer> createState() => _FullScreenImageViewerState();
}

class _FullScreenImageViewerState extends State<FullScreenImageViewer> {
  late PageController _pageController;
  late int _currentIndex;
  String? _docsDirPath;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: widget.initialIndex);
    _initDir();
  }

  Future<void> _initDir() async {
    final dir = await getApplicationDocumentsDirectory();
    if (mounted) {
      setState(() => _docsDirPath = dir.path);
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const host =
        'api'
        '.github.com';

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text(
          widget.imagePaths.length > 1
              ? '${_currentIndex + 1} / ${widget.imagePaths.length}'
              : 'Xem ảnh',
          style: const TextStyle(fontSize: 16),
        ),
      ),
      body: _docsDirPath == null
          ? const Center(child: CircularProgressIndicator(color: Colors.white))
          : PageView.builder(
              controller: _pageController,
              itemCount: widget.imagePaths.length,
              onPageChanged: (idx) => setState(() => _currentIndex = idx),
              itemBuilder: (context, index) {
                final path = widget.imagePaths[index];
                final safeName = path.replaceAll('/', '_');
                final localFile = File('$_docsDirPath/img_$safeName');

                // Nếu ảnh đã có trong Cache -> dùng luôn file trên máy
                if (localFile.existsSync() && localFile.lengthSync() > 0) {
                  return InteractiveViewer(
                    minScale: 0.8,
                    maxScale: 4.0,
                    child: Center(
                      child: Image.file(localFile, fit: BoxFit.contain),
                    ),
                  );
                }

                // Nếu chưa có -> tải từ GitHub
                final url = Uri.https(
                  host,
                  '/repos/${widget.owner}/${widget.repo}/contents/$path',
                ).toString();

                return InteractiveViewer(
                  minScale: 0.8,
                  maxScale: 4.0,
                  child: Center(
                    child: Image.network(
                      url,
                      fit: BoxFit.contain,
                      headers: {
                        'Authorization': 'Bearer ${widget.token}',
                        'Accept': 'application/vnd.github.raw',
                        'User-Agent': 'Flutter-Journal-App',
                      },
                      loadingBuilder: (context, child, progress) {
                        if (progress == null) return child;
                        return const CircularProgressIndicator(
                          color: Colors.white,
                        );
                      },
                      errorBuilder: (context, error, stackTrace) => const Icon(
                        Icons.broken_image,
                        color: Colors.white54,
                        size: 48,
                      ),
                    ),
                  ),
                );
              },
            ),
    );
  }
}
