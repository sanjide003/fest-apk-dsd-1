// File: lib/utils/export_helper.dart
// Version: 1.0
// Description: Cross-platform file download helper (Web & Mobile).

import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:path_provider/path_provider.dart';
import 'package:open_file/open_file.dart';
import 'package:universal_html/html.dart' as html; // Safe HTML import

class ExportHelper {
  static Future<void> downloadCsv(String content, String fileName) async {
    if (kIsWeb) {
      // WEB LOGIC
      final bytes = content.codeUnits;
      final blob = html.Blob([bytes]);
      final url = html.Url.createObjectUrlFromBlob(blob);
      final anchor = html.AnchorElement(href: url)
        ..setAttribute("download", fileName)
        ..click();
      html.Url.revokeObjectUrl(url);
    } else {
      // MOBILE LOGIC (Android/iOS)
      try {
        final directory = await getApplicationDocumentsDirectory();
        final file = File('${directory.path}/$fileName');
        await file.writeAsString(content);
        
        // Open the file
        await OpenFile.open(file.path);
      } catch (e) {
        print("Error saving file: $e");
      }
    }
  }
}
