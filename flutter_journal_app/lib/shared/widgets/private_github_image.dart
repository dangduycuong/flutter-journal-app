import 'package:material_ui/material_ui.dart';

import '../screens/full_screen_image_viewer.dart';

class PrivateGitHubImage extends StatelessWidget {
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
  Widget build(BuildContext context) {
    const host =
        'api'
        '.github.com';
    final url = Uri.https(
      host,
      '/repos/$owner/$repo/contents/$imagePath',
    ).toString();

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => FullScreenImageViewer(
              owner: owner,
              repo: repo,
              token: token,
              imagePaths: allImagePaths ?? [imagePath],
              initialIndex: initialIndex,
            ),
          ),
        );
      },
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image.network(
          url,
          height: height,
          width: width,
          fit: BoxFit.cover,
          headers: {
            'Authorization': 'Bearer $token',
            'Accept': 'application/vnd.github.raw',
            'User-Agent': 'Flutter-Journal-App',
          },
          loadingBuilder: (context, child, progress) {
            if (progress == null) return child;
            return Container(
              height: height ?? 150,
              width: width ?? double.infinity,
              color: Colors.grey.shade200,
              child: const Center(
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            );
          },
          errorBuilder: (context, error, stackTrace) => Container(
            height: height ?? 150,
            width: width ?? double.infinity,
            color: Colors.grey.shade200,
            child: const Icon(Icons.broken_image, color: Colors.grey),
          ),
        ),
      ),
    );
  }
}
