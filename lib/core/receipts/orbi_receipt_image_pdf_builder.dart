import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

class OrbiReceiptImagePdfBuilder {
  const OrbiReceiptImagePdfBuilder._();

  static Future<Uint8List> build({required Uint8List receiptPngBytes}) async {
    final doc = pw.Document();
    final image = pw.MemoryImage(receiptPngBytes);

    doc.addPage(
      pw.Page(
        pageTheme: const pw.PageTheme(
          pageFormat: PdfPageFormat.a4,
          margin: pw.EdgeInsets.symmetric(horizontal: 24, vertical: 28),
        ),
        build: (context) {
          return pw.Center(
            child: pw.Container(
              constraints: const pw.BoxConstraints(maxWidth: 460),
              child: pw.Image(image, fit: pw.BoxFit.contain),
            ),
          );
        },
      ),
    );

    return doc.save();
  }
}
