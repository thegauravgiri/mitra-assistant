import 'dart:io';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import '../../../core/utils/logger.dart';
import '../domain/models/meeting_session.dart';

class CsvExportService {
  static Future<File?> exportSessionToCsv(MeetingSession session) async {
    try {
      final buffer = StringBuffer();
      // CSV Header
      buffer.writeln('Timestamp,Speaker,Transcript');

      final timeFormat = DateFormat('yyyy-MM-dd HH:mm:ss');

      for (final entry in session.entries) {
        final timestampStr = timeFormat.format(entry.timestamp);
        final speakerStr = _escapeCsv(entry.speaker);
        final textStr = _escapeCsv(entry.text);
        buffer.writeln('$timestampStr,$speakerStr,$textStr');
      }

      final Directory appDocsDir = await getApplicationDocumentsDirectory();
      final Directory exportDir = Directory('${appDocsDir.path}/MitraAssistant');
      if (!await exportDir.exists()) {
        await exportDir.create(recursive: true);
      }

      final fileDateFormat = DateFormat('yyyyMMdd_HHmmss').format(session.startTime);
      final sanitizedTitle = session.title
          .replaceAll(RegExp(r'[^\w\s\-]'), '')
          .replaceAll(RegExp(r'\s+'), '_')
          .trim();
      final fileName = '${sanitizedTitle.isEmpty ? "meeting" : sanitizedTitle}_$fileDateFormat.csv';

      final file = File('${exportDir.path}/$fileName');
      await file.writeAsString(buffer.toString());

      AppLogger.log('Exported session CSV to ${file.path}');
      return file;
    } catch (e) {
      AppLogger.error('Error exporting session to CSV', e);
      return null;
    }
  }

  static String _escapeCsv(String field) {
    if (field.contains(',') || field.contains('"') || field.contains('\n')) {
      final escaped = field.replaceAll('"', '""');
      return '"$escaped"';
    }
    return field;
  }
}
