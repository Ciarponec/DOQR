import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:printing/printing.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../l10n/app_language.dart';
import '../services/qr_pdf_service.dart';
import '../ui/app_theme.dart';
import '../widgets/app_shell.dart';

class DoorQrScreen extends StatefulWidget {
  final String doorLabel;
  final String qrUrl;
  final String tokenId;

  const DoorQrScreen({
    super.key,
    required this.doorLabel,
    required this.qrUrl,
    required this.tokenId,
  });

  @override
  State<DoorQrScreen> createState() => _DoorQrScreenState();
}

class _DoorQrScreenState extends State<DoorQrScreen> {
  late final TextEditingController _topTextController;
  late final TextEditingController _bottomTextController;
  bool _isPreparingPdf = false;

  @override
  void initState() {
    super.initState();
    _topTextController = TextEditingController();
    _bottomTextController = TextEditingController();
    _topTextController.addListener(_refreshPreview);
    _bottomTextController.addListener(_refreshPreview);
  }

  @override
  void dispose() {
    _topTextController
      ..removeListener(_refreshPreview)
      ..dispose();
    _bottomTextController
      ..removeListener(_refreshPreview)
      ..dispose();
    super.dispose();
  }

  void _refreshPreview() => setState(() {});

  Future<Uint8List> _buildPdf() => QrPdfService.build(
        doorLabel: widget.doorLabel,
        qrUrl: widget.qrUrl,
        topText: _topTextController.text,
        bottomText: _bottomTextController.text,
      );

  Future<void> _sharePdf() async {
    await _runPdfAction(() async {
      final bytes = await _buildPdf();
      await Printing.sharePdf(
        bytes: bytes,
        filename: _fileName,
      );
    });
  }

  Future<void> _savePdf() async {
    await _runPdfAction(() async {
      await Printing.layoutPdf(
        name: _fileName,
        onLayout: (_) => _buildPdf(),
      );
    });
  }

  Future<void> _runPdfAction(Future<void> Function() action) async {
    setState(() => _isPreparingPdf = true);
    try {
      await action();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error.toString())),
        );
      }
    } finally {
      if (mounted) setState(() => _isPreparingPdf = false);
    }
  }

  String get _fileName {
    final safeLabel = widget.doorLabel
        .trim()
        .replaceAll(RegExp(r'[^a-zA-Z0-9_-]+'), '-')
        .replaceAll(RegExp(r'-+'), '-');
    return 'doqr-${safeLabel.isEmpty ? 'qr' : safeLabel}.pdf';
  }

  @override
  Widget build(BuildContext context) {
    final topText = _topTextController.text.trim();
    final bottomText = _bottomTextController.text.trim();

    return AppShell(
      title: 'QR • ${widget.doorLabel}',
      child: ListView(
        children: [
          ElevCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  context.tr('PDF için metinleri özelleştir',
                      'Customize the text for your PDF'),
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 6),
                Text(
                  context.tr(
                      'Bu alanlar yalnızca QR çıktısında görünür; QR bağlantısını değiştirmez.',
                      'These fields only appear on the QR printout; they do not change the QR link.'),
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppColors.muted,
                      ),
                ),
                const SizedBox(height: 18),
                TextField(
                  controller: _topTextController,
                  maxLength: 120,
                  textInputAction: TextInputAction.next,
                  decoration: InputDecoration(
                    labelText: context.tr(
                        'QR üstü metin (opsiyonel)', 'Text above QR (optional)'),
                    hintText: context.tr(
                        'Örn. XYZ sitesi - B blok', 'e.g. XYZ site - Block B'),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _bottomTextController,
                  maxLength: 120,
                  textInputAction: TextInputAction.done,
                  decoration: InputDecoration(
                    labelText: context.tr('QR altı metin (opsiyonel)',
                        'Text below QR (optional)'),
                    hintText: context.tr('Örn. Daire 6 için taratın',
                        'e.g. Scan for apartment 6'),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          ElevCard(
            child: Column(
              children: [
                Text(
                  context.tr('PDF önizlemesi', 'PDF preview'),
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 18),
                if (topText.isNotEmpty) ...[
                  Text(topText,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 12),
                ],
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: AppColors.line),
                  ),
                  child: QrImageView(
                      data: widget.qrUrl,
                      version: QrVersions.auto,
                      size: 250),
                ),
                if (bottomText.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Text(bottomText,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.titleMedium),
                ],
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: _isPreparingPdf ? null : _sharePdf,
                        icon: const Icon(Icons.share_rounded),
                        label: Text(context.tr('PDF paylaş', 'Share PDF')),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _isPreparingPdf ? null : _savePdf,
                        icon: const Icon(Icons.download_rounded),
                        label: Text(context.tr(
                            'PDF kaydet', 'Save PDF')),
                      ),
                    ),
                  ],
                ),
                if (_isPreparingPdf) ...[
                  const SizedBox(height: 12),
                  const LinearProgressIndicator(),
                ],
                const SizedBox(height: 18),
                Align(
                    alignment: Alignment.centerLeft,
                    child: Text(context.tr('QR Linki', 'QR Link'))),
                const SizedBox(height: 4),
                SelectableText(widget.qrUrl),
                const SizedBox(height: 8),
                Align(
                    alignment: Alignment.centerLeft,
                    child: Text(context.tr('Token ID', 'Token ID'))),
                const SizedBox(height: 4),
                SelectableText(widget.tokenId),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
