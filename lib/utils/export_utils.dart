import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_test_application_1/models/detection_history_entry.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:share_plus/share_plus.dart';

/// Utility class for exporting detection history data
class ExportUtils {
  /// Export a list of history entries to CSV and share the file
  static Future<void> exportToCsv(List<DetectionHistoryEntry> entries) async {
    if (entries.isEmpty) {
      throw Exception('No entries to export');
    }

    try {
      // Create CSV content
      final csvData = _generateCsv(entries);

      // Get temporary directory
      final directory = await getTemporaryDirectory();
      final path =
          '${directory.path}/detection_history_${DateTime.now().millisecondsSinceEpoch}.csv';

      // Write to file
      final file = File(path);
      await file.writeAsString(csvData);

      // Share the file
      await Share.shareXFiles([
        XFile(path),
      ], text: 'Plant Disease Detection History');
    } catch (e) {
      if (kDebugMode) {
        print('Error exporting CSV: $e');
      }
      rethrow;
    }
  }

  /// Request storage permission for saving files (Android)
  static Future<bool> requestStoragePermission() async {
    // On web or iOS, permission not needed
    if (kIsWeb || Platform.isIOS || Platform.isMacOS) {
      return true;
    }

    // Request permission on Android
    if (Platform.isAndroid) {
      final status = await Permission.storage.request();
      return status.isGranted;
    }

    return false;
  }

  /// Generate CSV content from entries
  static String _generateCsv(List<DetectionHistoryEntry> entries) {
    // Headers
    final headers = [
      'Date',
      'Plant ID',
      'Status',
      'Disease Name',
      'Confidence',
      'Plant Type',
    ];

    // Format each entry as a CSV row
    final rows =
        entries.map((entry) {
          // Added null checks for safety
          return [
            entry.analysisDate ?? 'N/A',
            entry.plant.plantId ?? 'N/A',
            entry.status ?? 'N/A',
            entry.diseaseName ?? 'N/A',
            entry.confidence?.toString() ?? 'N/A',
            entry.plantType ?? 'N/A',
          ];
        }).toList();

    // Combine headers and rows
    final allRows = [headers, ...rows];

    // Convert to CSV format
    return allRows.map((row) => row.join(',')).join('\n');
  }
}
