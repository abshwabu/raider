import 'package:flutter/material.dart';
import 'package:ai_book_reader/features/reader/reader_shell.dart';

class ReaderScreen extends StatelessWidget {
  final String bookId;

  const ReaderScreen({
    super.key,
    required this.bookId,
  });

  @override
  Widget build(BuildContext context) {
    return ReaderShell(bookId: bookId);
  }
}
