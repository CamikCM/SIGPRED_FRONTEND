class FileExporter {
  static void downloadText({
    required String fileName,
    required String content,
    String mimeType = 'text/plain;charset=utf-8',
  }) {
    throw UnsupportedError(
      'La descarga de archivos desde esta vista solo está disponible en Flutter Web.',
    );
  }

  static void downloadBytes({
    required String fileName,
    required List<int> bytes,
    String mimeType = 'application/octet-stream',
  }) {
    throw UnsupportedError(
      'La descarga de archivos desde esta vista solo está disponible en Flutter Web.',
    );
  }

  static void previewBytes({
    required List<int> bytes,
    String mimeType = 'application/pdf',
  }) {
    throw UnsupportedError(
      'La vista previa de archivos desde esta vista solo está disponible en Flutter Web.',
    );
  }
}
