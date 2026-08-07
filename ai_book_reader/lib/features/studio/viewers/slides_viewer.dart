import 'dart:convert';
import 'package:flutter/material.dart';
import '../../ai/studio/studio_payloads.dart';

class SlidesViewer extends StatefulWidget {
  final String payloadJson;

  const SlidesViewer({super.key, required this.payloadJson});

  @override
  State<SlidesViewer> createState() => _SlidesViewerState();
}

class _SlidesViewerState extends State<SlidesViewer> {
  late final SlidesPayload _payload;
  late final PageController _controller;
  int _index = 0;

  @override
  void initState() {
    super.initState();
    _payload = SlidesPayload.fromJson(
      Map<String, dynamic>.from(jsonDecode(widget.payloadJson) as Map),
    );
    _controller = PageController();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final slides = _payload.slides;

    return Scaffold(
      appBar: AppBar(title: Text(_payload.title)),
      body: slides.isEmpty
          ? const Center(child: Text('No slides'))
          : Column(
              children: [
                Expanded(
                  child: PageView.builder(
                    controller: _controller,
                    itemCount: slides.length,
                    onPageChanged: (i) => setState(() => _index = i),
                    itemBuilder: (context, i) {
                      final slide = slides[i];
                      return Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              slide.heading,
                              style: theme.textTheme.headlineSmall?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 20),
                            ...slide.bullets.map(
                              (b) => Padding(
                                padding: const EdgeInsets.only(bottom: 10),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('•  ', style: theme.textTheme.titleMedium),
                                    Expanded(
                                      child: Text(
                                        b,
                                        style: theme.textTheme.titleMedium
                                            ?.copyWith(height: 1.35),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            if (slide.speakerNote != null &&
                                slide.speakerNote!.trim().isNotEmpty) ...[
                              const Spacer(),
                              Text(
                                'Note: ${slide.speakerNote}',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                            ],
                          ],
                        ),
                      );
                    },
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                  child: Row(
                    children: [
                      IconButton(
                        onPressed: _index == 0
                            ? null
                            : () => _controller.previousPage(
                                  duration: const Duration(milliseconds: 250),
                                  curve: Curves.easeOut,
                                ),
                        icon: const Icon(Icons.chevron_left),
                      ),
                      Expanded(
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: List.generate(slides.length, (i) {
                            return Container(
                              width: 8,
                              height: 8,
                              margin: const EdgeInsets.symmetric(horizontal: 3),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: i == _index
                                    ? theme.colorScheme.primary
                                    : theme.colorScheme.outlineVariant,
                              ),
                            );
                          }),
                        ),
                      ),
                      IconButton(
                        onPressed: _index >= slides.length - 1
                            ? null
                            : () => _controller.nextPage(
                                  duration: const Duration(milliseconds: 250),
                                  curve: Curves.easeOut,
                                ),
                        icon: const Icon(Icons.chevron_right),
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}
