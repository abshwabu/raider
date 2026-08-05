class SupportedFormats {
  static const String pdf = 'pdf';
  static const String epub = 'epub';
  static const String txt = 'txt';
  static const String docx = 'docx';
  static const String cbz = 'cbz';
  static const String cbr = 'cbr';
  static const String mobi = 'mobi';
  static const String azw3 = 'azw3';

  static const List<String> extensions = [
    pdf,
    epub,
    txt,
    docx,
    cbz,
    cbr,
    mobi,
    azw3,
  ];

  static bool isSupported(String extension) {
    final cleanExt = extension.toLowerCase().replaceAll('.', '').trim();
    return extensions.contains(cleanExt);
  }

  static String normalizeExtension(String filePath) {
    final ext = filePath.split('.').last.toLowerCase().trim();
    return ext;
  }
}
