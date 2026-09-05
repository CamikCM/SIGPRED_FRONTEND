import 'dart:convert';

import 'package:web/web.dart' as web;

class FileExporter {
  static void downloadText({
    required String fileName,
    required String content,
    String mimeType = 'text/plain;charset=utf-8',
  }) {
    final bytes = utf8.encode('\uFEFF$content');
    final encoded = base64Encode(bytes);
    final dataUrl = 'data:$mimeType;base64,$encoded';

    final anchor = web.HTMLAnchorElement()
      ..href = dataUrl
      ..download = fileName
      ..style.display = 'none';

    final body = web.document.body;
    body?.appendChild(anchor);
    anchor.click();
    anchor.remove();
  }

  static void downloadBytes({
    required String fileName,
    required List<int> bytes,
    String mimeType = 'application/octet-stream',
  }) {
    final encoded = base64Encode(bytes);
    final dataUrl = 'data:$mimeType;base64,$encoded';
    final anchor = web.HTMLAnchorElement()
      ..href = dataUrl
      ..download = fileName
      ..style.display = 'none';
    final body = web.document.body;
    body?.appendChild(anchor);
    anchor.click();
    anchor.remove();
  }

  static void previewBytes({
    required List<int> bytes,
    String mimeType = 'application/pdf',
  }) {
    final encoded = base64Encode(bytes);
    final dataUrl = 'data:$mimeType;base64,$encoded';
    final anchor = web.HTMLAnchorElement()
      ..href = dataUrl
      ..target = '_blank'
      ..style.display = 'none';
    final body = web.document.body;
    body?.appendChild(anchor);
    anchor.click();
    anchor.remove();
  }
}
