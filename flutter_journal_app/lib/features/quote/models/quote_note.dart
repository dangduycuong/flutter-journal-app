class QuoteNote {
  final String id;
  final String content;
  final String? author; // Tác giả hoặc nguồn trích dẫn (tùy chọn)
  final DateTime createdAt; // Ngày tạo
  final List<String> imageUrls; // Danh sách ảnh đính kèm

  QuoteNote({
    required this.id,
    required this.content,
    this.author,
    required this.createdAt,
    this.imageUrls = const [],
  });

  factory QuoteNote.fromJson(Map<String, dynamic> json) {
    return QuoteNote(
      id: json['id'] as String,
      content: json['content'] as String,
      author: json['author'] as String?,
      createdAt: DateTime.parse(json['createdAt'] as String),
      imageUrls: List<String>.from(json['imageUrls'] ?? []),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'content': content,
      'author': author,
      'createdAt': createdAt.toIso8601String(),
      'imageUrls': imageUrls,
    };
  }
}
