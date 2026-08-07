import 'dart:convert';
import 'package:flutter/material.dart';
import '../../ai/studio/studio_payloads.dart';
import '../widgets/studio_markdown.dart';

class StudyGuideViewer extends StatelessWidget {
  final String payloadJson;

  const StudyGuideViewer({super.key, required this.payloadJson});

  @override
  Widget build(BuildContext context) {
    StudyGuidePayload payload;
    try {
      final decoded = jsonDecode(payloadJson);
      if (decoded is Map) {
        payload = StudyGuidePayload.fromJson(Map<String, dynamic>.from(decoded));
      } else {
        payload = StudyGuidePayload.fromRaw(payloadJson);
      }
    } catch (_) {
      payload = StudyGuidePayload.fromRaw(payloadJson);
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Study guide')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          StudioMarkdown(data: payload.markdown),
        ],
      ),
    );
  }
}
