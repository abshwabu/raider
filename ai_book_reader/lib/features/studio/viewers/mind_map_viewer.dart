import 'dart:convert';
import 'package:flutter/material.dart';
import '../../ai/studio/studio_payloads.dart';

class MindMapViewer extends StatelessWidget {
  final String payloadJson;

  const MindMapViewer({super.key, required this.payloadJson});

  @override
  Widget build(BuildContext context) {
    final payload = MindMapPayload.fromJson(
      Map<String, dynamic>.from(jsonDecode(payloadJson) as Map),
    );

    return Scaffold(
      appBar: AppBar(title: const Text('Mind map')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _MindMapNodeTile(node: payload.root, depth: 0),
        ],
      ),
    );
  }
}

class _MindMapNodeTile extends StatelessWidget {
  final MindMapNode node;
  final int depth;

  const _MindMapNodeTile({required this.node, required this.depth});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasChildren = node.children.isNotEmpty;

    if (!hasChildren) {
      return Padding(
        padding: EdgeInsets.only(left: depth * 16.0, bottom: 6),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              Icons.circle,
              size: depth == 0 ? 10 : 8,
              color: theme.colorScheme.primary,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                node.label,
                style: depth == 0
                    ? theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      )
                    : theme.textTheme.bodyLarge,
              ),
            ),
          ],
        ),
      );
    }

    return Theme(
      data: theme.copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        initiallyExpanded: depth < 2,
        tilePadding: EdgeInsets.only(left: depth * 8.0),
        title: Text(
          node.label,
          style: depth == 0
              ? theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)
              : theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
        ),
        children: node.children
            .map((child) => _MindMapNodeTile(node: child, depth: depth + 1))
            .toList(),
      ),
    );
  }
}
