class VietnameseHelper {
  static String removeDiacritics(String text) {
    const vietnameseMap = <String, String>{
      'a': 'àáạảãâầấậẩẫăằắặẳẵ',
      'e': 'èéẹẻẽêềếệểễ',
      'i': 'ìíịỉĩ',
      'o': 'òóọỏõôồốộổỗơờớợởỡ',
      'u': 'ùúụủũưừứựửữ',
      'y': 'ỳýỵỷỹ',
      'd': 'đ',
    };

    String result = text.toLowerCase();
    vietnameseMap.forEach((nonAccent, accents) {
      for (int i = 0; i < accents.length; i++) {
        result = result.replaceAll(accents[i], nonAccent);
      }
    });
    return result;
  }

  // Kiểm tra xem nội dung có chứa từ khóa không (hỗ trợ cả có dấu và không dấu)
  static bool matches(String source, String keyword) {
    final normalizedSource = removeDiacritics(source);
    final normalizedKeyword = removeDiacritics(keyword.trim());
    return normalizedSource.contains(normalizedKeyword);
  }
}
