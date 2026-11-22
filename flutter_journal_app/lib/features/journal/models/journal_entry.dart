class JournalEntry {
  final String id;
  final String title;
  final String content;
  final DateTime entryDate; // Ngày ghi (ngày nội dung biểu đạt)
  final DateTime createdAt; // Ngày tạo bản ghi thực tế
  final DateTime updatedAt; // Ngày chỉnh sửa gần nhất
  final List<String> imageUrls; // Danh sách đường dẫn ảnh trên GitHub

  JournalEntry({
    required this.id,
    this.title = '',
    required this.content,
    required this.entryDate,
    required this.createdAt,
    required this.updatedAt,
    this.imageUrls = const [],
  });

  factory JournalEntry.fromJson(Map<String, dynamic> json) {
    return JournalEntry(
      id: json['id'] as String,
      title: json['title'] as String? ?? '',
      content: json['content'] as String,
      entryDate: DateTime.parse(json['entryDate'] as String),
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
      imageUrls: List<String>.from(json['imageUrls'] ?? []),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'content': content,
      'entryDate': entryDate.toIso8601String(),
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'imageUrls': imageUrls,
    };
  }

  JournalEntry copyWith({
    String? title,
    String? content,
    DateTime? entryDate,
    DateTime? updatedAt,
    List<String>? imageUrls,
  }) {
    return JournalEntry(
      id: id,
      title: title ?? this.title,
      content: content ?? this.content,
      entryDate: entryDate ?? this.entryDate,
      createdAt: createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
      imageUrls: imageUrls ?? this.imageUrls,
    );
  }
}
