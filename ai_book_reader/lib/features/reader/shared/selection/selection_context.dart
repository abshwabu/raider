class SelectionContext {
  final int bookId;
  final String bookTitle;
  final int chapterId;
  final String selectedText;
  final int startOffset;
  final int endOffset;

  const SelectionContext({
    required this.bookId,
    required this.bookTitle,
    required this.chapterId,
    required this.selectedText,
    required this.startOffset,
    required this.endOffset,
  });

  bool get isValid => selectedText.trim().isNotEmpty;
}
