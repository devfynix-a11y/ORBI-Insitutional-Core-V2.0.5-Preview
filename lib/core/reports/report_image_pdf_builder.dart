import 'dart:typed_data';

import 'package:image/image.dart' as img;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

class OrbiReportImagePdfBuilder {
  const OrbiReportImagePdfBuilder._();

  static Future<Uint8List> build({required Uint8List reportPngBytes}) async {
    final doc = pw.Document();
    final source = img.decodeImage(reportPngBytes);
    if (source == null) {
      throw StateError('Could not decode report preview image.');
    }

    const basePageFormat = PdfPageFormat.a4;
    const margin = pw.EdgeInsets.symmetric(horizontal: 6, vertical: 8);
    const footerHeight = 14.0;
    final drawableWidth = basePageFormat.availableWidth - margin.horizontal;
    final maxDrawableHeight = basePageFormat.availableHeight - margin.vertical;
    final imageHeightOnPage = maxDrawableHeight - footerHeight;
    final sliceHeight = (source.width * imageHeightOnPage / drawableWidth)
        .floor()
        .clamp(1, source.height);
    final slices = <Uint8List>[];

    var y = 0;
    while (y < source.height) {
      final remaining = source.height - y;
      var height = remaining.clamp(1, sliceHeight);
      if (remaining > sliceHeight) {
        final safeCut = _findSafeCut(source, y + sliceHeight);
        height = (safeCut - y).clamp(1, sliceHeight);
      }
      final slice = img.copyCrop(
        source,
        x: 0,
        y: y,
        width: source.width,
        height: height,
      );
      slices.add(Uint8List.fromList(img.encodePng(slice)));
      y += height;
    }

    for (var index = 0; index < slices.length; index += 1) {
      final pageImage = pw.MemoryImage(slices[index]);
      final slice = img.decodeImage(slices[index]);
      final sliceAspectHeight = slice == null
          ? imageHeightOnPage
          : (slice.height * drawableWidth / slice.width);
      final pageHeight = (sliceAspectHeight + margin.vertical + footerHeight + 6)
          .clamp(160.0, basePageFormat.height);
      final pageFormat = PdfPageFormat(basePageFormat.width, pageHeight);
      doc.addPage(
        pw.Page(
          pageTheme: pw.PageTheme(pageFormat: pageFormat, margin: margin),
          build: (context) {
            return pw.Column(
              mainAxisSize: pw.MainAxisSize.min,
              children: [
                pw.Align(
                  alignment: pw.Alignment.topCenter,
                  child: pw.Image(
                    pageImage,
                    width: drawableWidth,
                    fit: pw.BoxFit.fitWidth,
                  ),
                ),
                pw.SizedBox(height: 4),
                pw.Align(
                  alignment: pw.Alignment.centerRight,
                  child: pw.Text(
                    'Page ${index + 1} of ${slices.length}',
                    style: const pw.TextStyle(
                      color: PdfColor.fromInt(0xFF64748B),
                      fontSize: 8,
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      );
    }

    return doc.save();
  }

  static int _findSafeCut(img.Image source, int targetY) {
    final minY = (targetY - 180).clamp(1, source.height - 1);
    final maxY = (targetY + 80).clamp(1, source.height - 1);
    var bestY = targetY.clamp(minY, maxY);
    var bestScore = double.infinity;

    for (var y = minY; y <= maxY; y += 1) {
      var ink = 0;
      for (var x = 0; x < source.width; x += 8) {
        final pixel = source.getPixel(x, y);
        if (pixel.r < 238 || pixel.g < 238 || pixel.b < 238) {
          ink += 1;
        }
      }
      final distancePenalty = (targetY - y).abs() / 12;
      final score = ink + distancePenalty;
      if (score < bestScore) {
        bestScore = score;
        bestY = y;
      }
    }
    return bestY;
  }
}
