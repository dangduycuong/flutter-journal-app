import 'package:material_ui/material_ui.dart';

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

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: widget.initialIndex);
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
      body: PageView.builder(
        controller: _pageController,
        itemCount: widget.imagePaths.length,
        onPageChanged: (idx) => setState(() => _currentIndex = idx),
        itemBuilder: (context, index) {
          final url = Uri.https(
            host,
            '/repos/${widget.owner}/${widget.repo}/contents/${widget.imagePaths[index]}',
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
                  return const CircularProgressIndicator(color: Colors.white);
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
