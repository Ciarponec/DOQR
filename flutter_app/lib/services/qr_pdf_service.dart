import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:qr_flutter/qr_flutter.dart';

class QrPdfService {
  static Future<Uint8List> build({
    required String doorLabel,
    required String qrUrl,
    String? topText,
    String? bottomText,
  }) async {
    final qrData = await QrPainter(
      data: qrUrl,
      version: QrVersions.auto,
      gapless: true,
    ).toImageData(1000);
    if (qrData == null) {
      throw StateError('QR görseli oluşturulamadı.');
    }

    final fontData = await rootBundle.load('assets/fonts/Manrope-Variable.ttf');
    final font = pw.Font.ttf(fontData);
    final document = pw.Document(
      theme: pw.ThemeData.withFont(base: font, bold: font),
    );
    final qrImage = pw.MemoryImage(qrData.buffer.asUint8List());
    final normalizedTop = _clean(topText);
    final normalizedBottom = _clean(bottomText);

    document.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.fromLTRB(48, 42, 48, 42),
        build: (context) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.stretch,
          children: [
            pw.Text(
              'DOQR',
              textAlign: pw.TextAlign.center,
              style: pw.TextStyle(
                font: font,
                fontSize: 24,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.blue900,
              ),
            ),
            pw.SizedBox(height: 6),
            pw.Text(
              doorLabel,
              textAlign: pw.TextAlign.center,
              style: pw.TextStyle(
                font: font,
                fontSize: 16,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.grey800,
              ),
            ),
            pw.SizedBox(height: 30),
            if (normalizedTop != null) ...[
              pw.Text(
                normalizedTop,
                textAlign: pw.TextAlign.center,
                style: pw.TextStyle(
                  font: font,
                  fontSize: 18,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.black,
                ),
              ),
              pw.SizedBox(height: 16),
            ],
            pw.Center(
              child: pw.Container(
                width: 330,
                height: 330,
                padding: const pw.EdgeInsets.all(12),
                decoration: pw.BoxDecoration(
                  color: PdfColors.white,
                  border: pw.Border.all(color: PdfColors.grey300, width: 1),
                  borderRadius: pw.BorderRadius.circular(8),
                ),
                child: pw.Image(qrImage, fit: pw.BoxFit.contain),
              ),
            ),
            if (normalizedBottom != null) ...[
              pw.SizedBox(height: 18),
              pw.Text(
                normalizedBottom,
                textAlign: pw.TextAlign.center,
                style: pw.TextStyle(
                  font: font,
                  fontSize: 18,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.black,
                ),
              ),
            ],
            pw.Spacer(),
            pw.Divider(color: PdfColors.grey300),
            pw.SizedBox(height: 8),
            pw.Text(
              'Ziyaretçi bu QR kodu telefon kamerasıyla tarayarak dijital zile ulaşabilir.',
              textAlign: pw.TextAlign.center,
              style: pw.TextStyle(
                font: font,
                fontSize: 9,
                color: PdfColors.grey600,
              ),
            ),
          ],
        ),
      ),
    );

    return document.save();
  }

  static String? _clean(String? value) {
    final text = value?.trim();
    return text == null || text.isEmpty ? null : text;
  }
}
