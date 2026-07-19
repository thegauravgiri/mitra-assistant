import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../domain/models/uploaded_document.dart';
import '../providers/document_providers.dart';

class DocumentChipsBar extends ConsumerWidget {
  const DocumentChipsBar({super.key});

  IconData _getFileIcon(String fileType) {
    switch (fileType) {
      case 'pdf':
        return Icons.picture_as_pdf_rounded;
      case 'docx':
        return Icons.description_rounded;
      case 'md':
        return Icons.code_rounded;
      case 'txt':
      default:
        return Icons.text_snippet_rounded;
    }
  }

  Color _getFileColor(String fileType) {
    switch (fileType) {
      case 'pdf':
        return const Color(0xFFEF4444);
      case 'docx':
        return const Color(0xFF3B82F6);
      case 'md':
        return const Color(0xFF10B981);
      case 'txt':
      default:
        return const Color(0xFF9CA3AF);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final docState = ref.watch(documentNotifierProvider);
    final docs = docState.documents;

    if (docs.isEmpty) return const SizedBox.shrink();

    final notifier = ref.read(documentNotifierProvider.notifier);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 6.0),
      decoration: BoxDecoration(
        color: const Color(0xFF12141C).withValues(alpha: 0.85),
        border: Border(
          top: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
        ),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        child: Row(
          children: docs.map((doc) {
            final fileColor = _getFileColor(doc.fileType);
            final isPinned = doc.isPinned;
            final isError = doc.status == DocStatus.error;
            final isProcessing = doc.status == DocStatus.parsing ||
                doc.status == DocStatus.summarizing;

            return Container(
              margin: const EdgeInsets.only(right: 8.0),
              padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
              decoration: BoxDecoration(
                color: isPinned
                    ? Colors.amber.withValues(alpha: 0.15)
                    : (isError
                        ? Colors.red.withValues(alpha: 0.15)
                        : Colors.white.withValues(alpha: 0.06)),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isPinned
                      ? Colors.amber.withValues(alpha: 0.5)
                      : (isError
                          ? Colors.red.withValues(alpha: 0.5)
                          : Colors.white.withValues(alpha: 0.12)),
                  width: 1,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // File type icon
                  Icon(
                    _getFileIcon(doc.fileType),
                    size: 14,
                    color: fileColor,
                  ),
                  const SizedBox(width: 6),
                  // File name
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 120),
                    child: Text(
                      doc.fileName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.9),
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  // Status indicator
                  if (isProcessing) ...[
                    const SizedBox(
                      width: 10,
                      height: 10,
                      child: CircularProgressIndicator(
                        strokeWidth: 1.5,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.cyanAccent),
                      ),
                    ),
                    const SizedBox(width: 4),
                  ] else if (isError) ...[
                    Tooltip(
                      message: doc.error ?? 'Error processing document',
                      child: const Icon(
                        Icons.error_outline_rounded,
                        size: 14,
                        color: Colors.redAccent,
                      ),
                    ),
                    const SizedBox(width: 2),
                  ],
                  // Pin toggle button
                  if (!isError)
                    InkWell(
                      onTap: () => notifier.togglePin(doc.id),
                      borderRadius: BorderRadius.circular(12),
                      child: Padding(
                        padding: const EdgeInsets.all(2.0),
                        child: Icon(
                          isPinned ? Icons.push_pin_rounded : Icons.push_pin_outlined,
                          size: 13,
                          color: isPinned ? Colors.amber : Colors.white54,
                        ),
                      ),
                    ),
                  // Delete button
                  InkWell(
                    onTap: () => notifier.removeDocument(doc.id),
                    borderRadius: BorderRadius.circular(12),
                    child: const Padding(
                      padding: EdgeInsets.all(2.0),
                      child: Icon(
                        Icons.close_rounded,
                        size: 13,
                        color: Colors.white54,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
}
