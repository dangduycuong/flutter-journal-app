import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:material_ui/material_ui.dart';
import 'package:path_provider/path_provider.dart';

import '../screens/full_screen_image_viewer.dart';

class PrivateGitHubImage extends StatefulWidget {
  final String owner;
  final String repo;
  final String token;
  final String imagePath;
  final List<String>? allImagePaths;
  final int initialIndex;
  final double? height;
  final double? width;

  const PrivateGitHubImage({
    super.key,
    required this.owner,
    required this.repo,
    required this.token,
    required this.imagePath,
    this.allImagePaths,
    this.initialIndex = 0,
    this.height,
    this.width,
  });

  @override
  State<PrivateGitHubImage> createState() => _PrivateGitHubImageState();
}

class _PrivateGitHubImageState extends State<PrivateGitHubImage> {
  File? _cachedImageFile;
  bool _isLoading = true;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _loadImage();
  }

  @override
  void didUpdateWidget(covariant PrivateGitHubImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.imagePath != widget.imagePath) {
      _loadImage();
    }
  }

  Future<void> _loadImage() async {
    setState(() {
      _isLoading = true;
      _hasError = false;
    });

    try {
      final dir = await getApplicationDocumentsDirectory();
      final safeName = widget.imagePath.replaceAll('/', '_');
      final localFile = File('${dir.path}/img_$safeName');

      // 1. Nếu ảnh đã lưu trong máy -> dùng ngay lập tức (hỗ trợ Offline)
      if (await localFile.exists() && await localFile.length() > 0) {
        if (mounted) {
          setState(() {
            _cachedImageFile = localFile;
            _isLoading = false;
          });
        }
        return;
      }

      // 2. Nếu chưa có -> tải từ GitHub về và lưu vào máy
      const host =
          'api'
          '.github.com';
      final url = Uri.https(
        host,
        '/repos/${widget.owner}/${widget.repo}/contents/${widget.imagePath}',
      );

      final response = await http.get(
        url,
        headers: {
          'Authorization': 'Bearer ${widget.token}',
          'Accept': 'application/vnd.github.raw',
          'User-Agent': 'Flutter-Journal-App',
        },
      );

      if (response.statusCode == 200) {
        await localFile.writeAsBytes(response.bodyBytes);
        if (mounted) {
          setState(() {
            _cachedImageFile = localFile;
            _isLoading = false;
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _hasError = true;
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _hasError = true;
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => FullScreenImageViewer(
              owner: widget.owner,
              repo: widget.repo,
              token: widget.token,
              imagePaths: widget.allImagePaths ?? [widget.imagePath],
              initialIndex: widget.initialIndex,
            ),
          ),
        );
      },
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: _isLoading
            ? Container(
                height: widget.height ?? 150,
                width: widget.width ?? double.infinity,
                color: Colors.grey.shade200,
                child: const Center(
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              )
            : (_hasError || _cachedImageFile == null)
            ? Container(
                height: widget.height ?? 150,
                width: widget.width ?? double.infinity,
                color: Colors.grey.shade200,
                child: const Icon(Icons.broken_image, color: Colors.grey),
              )
            : Image.file(
                _cachedImageFile!,
                height: widget.height,
                width: widget.width,
                fit: BoxFit.cover,
              ),
      ),
    );
  }
}
