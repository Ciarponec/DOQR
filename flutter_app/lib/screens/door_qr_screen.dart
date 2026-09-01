import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:printing/printing.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../l10n/app_language.dart';
import '../services/qr_pdf_service.dart';
import '../services/user_error.dart';
import '../ui/app_theme.dart';
import '../widgets/app_shell.dart';

class DoorQrScreen extends StatefulWidget {
  final String doorLabel;
  final String qrUrl;
  final int activeQrCount;
  final Future<String> Function()? onRotate;
  final Future<void> Function()? onRevokeAll;

  const DoorQrScreen({
    super.key,
    required this.doorLabel,
    required this.qrUrl,
    this.activeQrCount = 1,
    this.onRotate,
    this.onRevokeAll,
  });

  @override
  State<DoorQrScreen> createState() => _DoorQrScreenState();
}

class _DoorQrScreenState extends State<DoorQrScreen> {
  late final TextEditingController _topTextController;
  late final TextEditingController _bottomTextController;
  late final TextEditingController _sideTextController;
  QrPdfTemplate _template = QrPdfTemplate.minimal;
  bool _isPreparingPdf = false;
  bool _isManagingQr = false;
  late String _qrUrl;
  late int _activeQrCount;

  @override
  void initState() {
    super.initState();
    _qrUrl = widget.qrUrl;
    _activeQrCount = widget.activeQrCount;
    _topTextController = TextEditingController();
    _bottomTextController = TextEditingController();
    _sideTextController = TextEditingController();
    _topTextController.addListener(_refreshPreview);
    _bottomTextController.addListener(_refreshPreview);
    _sideTextController.addListener(_refreshPreview);
  }

  @override
  void dispose() {
    _topTextController
      ..removeListener(_refreshPreview)
      ..dispose();
    _bottomTextController
      ..removeListener(_refreshPreview)
      ..dispose();
    _sideTextController
      ..removeListener(_refreshPreview)
      ..dispose();
    super.dispose();
  }

  void _refreshPreview() => setState(() {});

  void _applyPreset(_QrTextPreset preset) {
    setState(() {
      _template = preset.template;
      _topTextController.text = preset.topTextFor(context);
      _bottomTextController.text = preset.bottomTextFor(context);
      _sideTextController.text = preset.sideTextFor(context);
    });
  }

  Future<Uint8List> _buildPdf() => QrPdfService.build(
        doorLabel: widget.doorLabel,
        qrUrl: _qrUrl,
        topText: _topTextController.text,
        bottomText: _bottomTextController.text,
        sideText: _sideTextController.text,
        template: _template,
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
          SnackBar(content: Text(userErrorMessage(error))),
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

  Future<bool> _confirm(String title, String message, String action) async =>
      await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(title),
          content: Text(message),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text(context.tr('Vazgeç', 'Cancel', 'Отмена'))),
            FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: Text(action)),
          ],
        ),
      ) ??
      false;

  Future<void> _rotateQr() async {
    final callback = widget.onRotate;
    if (callback == null ||
        !await _confirm(
          context.tr('QR kodu yenilensin mi?', 'Rotate the QR code?',
              'Обновить QR-код?'),
          context.tr(
              'Eski QR çıktıları hemen geçersiz olur. Yeni kodu yeniden yazdırmanız gerekir.',
              'Old QR printouts will stop working immediately. You will need to print the new code.',
              'Старые распечатки сразу перестанут работать. Новый код потребуется распечатать заново.'),
          context.tr('Yenile', 'Rotate', 'Обновить'),
        )) {
      return;
    }
    setState(() => _isManagingQr = true);
    try {
      final url = await callback();
      if (mounted) {
        setState(() {
          _qrUrl = url;
          _activeQrCount = 1;
        });
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(context.tr(
                'Yeni QR kodu hazır. Eski kodlar iptal edildi.',
                'The new QR code is ready. Old codes were revoked.',
                'Новый QR-код готов. Старые коды отозваны.'))));
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(userErrorMessage(error))));
      }
    } finally {
      if (mounted) setState(() => _isManagingQr = false);
    }
  }

  Future<void> _revokeAllQr() async {
    final callback = widget.onRevokeAll;
    if (callback == null ||
        !await _confirm(
          context.tr('Tüm QR kodları iptal edilsin mi?', 'Revoke all QR codes?',
              'Отозвать все QR-коды?'),
          context.tr(
              'Bu dijital zile ait hiçbir QR kodu yeni ziyaret başlatamayacak.',
              'No QR code for this doorbell will be able to start a new visit.',
              'Ни один QR-код этого звонка не сможет начать новый визит.'),
          context.tr('Tümünü iptal et', 'Revoke all', 'Отозвать все'),
        )) {
      return;
    }
    setState(() => _isManagingQr = true);
    try {
      await callback();
      if (mounted) Navigator.pop(context);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(userErrorMessage(error))));
      }
    } finally {
      if (mounted) setState(() => _isManagingQr = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final topText = _topTextController.text.trim();
    final bottomText = _bottomTextController.text.trim();
    final sideText = _sideTextController.text.trim();
    final previewBorder = switch (_template) {
      QrPdfTemplate.minimal => Border.all(color: AppColors.line),
      QrPdfTemplate.framed => Border.all(color: AppColors.blue, width: 4),
      QrPdfTemplate.poster => Border.all(color: AppColors.navy, width: 7),
    };
    final previewRadius = _template == QrPdfTemplate.minimal ? 18.0 : 28.0;

    return AppShell(
      title: context.tr('QR kodu', 'QR code'),
      child: ListView(
        children: [
          ElevCard(
            color: const Color(0xFFF1F5FF),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  context.tr(
                      'QR güvenliği', 'QR security', 'Безопасность QR-кода'),
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 6),
                Text(
                  context.tr(
                      '$_activeQrCount etkin QR kaydı var. Kodun paylaşıldığını düşünüyorsanız yenileyin.',
                      'There are $_activeQrCount active QR records. Rotate the code if you think it was shared.',
                      'Активных QR-кодов: $_activeQrCount. Обновите код, если он мог попасть к посторонним.'),
                  style: Theme.of(context)
                      .textTheme
                      .bodyMedium
                      ?.copyWith(color: AppColors.muted),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _isManagingQr ? null : _rotateQr,
                        icon: const Icon(Icons.refresh_rounded),
                        label: Text(context.tr('QR kodunu yenile',
                            'Rotate QR code', 'Обновить QR-код')),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton.outlined(
                      tooltip: context.tr('Tüm QR kodlarını iptal et',
                          'Revoke all QR codes', 'Отозвать все QR-коды'),
                      onPressed: _isManagingQr ? null : _revokeAllQr,
                      icon: const Icon(Icons.link_off_rounded),
                    ),
                  ],
                ),
                if (_isManagingQr) ...[
                  const SizedBox(height: 10),
                  const LinearProgressIndicator(),
                ],
              ],
            ),
          ),
          const SizedBox(height: 14),
          ElevCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  context.tr(
                      'QR çıktısını özelleştir', 'Customize your QR output'),
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
                Text(context.tr('Şablon', 'Template'),
                    style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _TemplateChoice(
                      selected: _template == QrPdfTemplate.minimal,
                      label: context.tr('Sade', 'Minimal'),
                      icon: Icons.crop_square_rounded,
                      onTap: () =>
                          setState(() => _template = QrPdfTemplate.minimal),
                    ),
                    _TemplateChoice(
                      selected: _template == QrPdfTemplate.framed,
                      label: context.tr('Çerçeveli', 'Framed'),
                      icon: Icons.filter_frames_rounded,
                      onTap: () =>
                          setState(() => _template = QrPdfTemplate.framed),
                    ),
                    _TemplateChoice(
                      selected: _template == QrPdfTemplate.poster,
                      label: context.tr('Afiş', 'Poster'),
                      icon: Icons.campaign_outlined,
                      onTap: () =>
                          setState(() => _template = QrPdfTemplate.poster),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                Text(
                    context.tr(
                        'Hazır kullanım şablonları', 'Ready-to-use presets'),
                    style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _QrTextPreset.values
                      .map((preset) => _TemplateChoice(
                            selected: false,
                            label: preset.labelFor(context),
                            icon: preset.icon,
                            onTap: () => _applyPreset(preset),
                          ))
                      .toList(),
                ),
                const SizedBox(height: 10),
                _QrTextField(
                    controller: _topTextController,
                    label: context.tr('QR üstü metin (opsiyonel)',
                        'Text above QR (optional)'),
                    hint: context.tr(
                        'Örn. XYZ sitesi - B blok', 'e.g. XYZ site - Block B')),
                const SizedBox(height: 10),
                _QrTextField(
                    controller: _bottomTextController,
                    label: context.tr('QR altı metin (opsiyonel)',
                        'Text below QR (optional)'),
                    hint: context.tr('Örn. Daire 6 için taratın',
                        'e.g. Scan for apartment 6')),
                const SizedBox(height: 10),
                _QrTextField(
                    controller: _sideTextController,
                    label: context.tr('QR yanı metin (opsiyonel)',
                        'Text beside QR (optional)'),
                    hint: context.tr(
                        'Örn. Ziyaretçi girişi', 'e.g. Visitor entrance')),
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
                if (_template == QrPdfTemplate.poster)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                        color: AppColors.navy,
                        borderRadius: BorderRadius.circular(12)),
                    child: const Text('DOQR',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            color: Colors.white, fontWeight: FontWeight.w800)),
                  ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Flexible(
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(previewRadius),
                          border: previewBorder,
                        ),
                        child: QrImageView(
                            data: _qrUrl,
                            version: QrVersions.auto,
                            size: sideText.isEmpty ? 250 : 210),
                      ),
                    ),
                    if (sideText.isNotEmpty) ...[
                      const SizedBox(width: 12),
                      Flexible(
                        child: Text(sideText,
                            style: Theme.of(context).textTheme.titleSmall),
                      ),
                    ],
                  ],
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
                        label: Text(context.tr('PDF kaydet', 'Save PDF')),
                      ),
                    ),
                  ],
                ),
                if (_isPreparingPdf) ...[
                  const SizedBox(height: 12),
                  const LinearProgressIndicator(),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TemplateChoice extends StatelessWidget {
  final bool selected;
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  const _TemplateChoice(
      {required this.selected,
      required this.label,
      required this.icon,
      required this.onTap});

  @override
  Widget build(BuildContext context) => ChoiceChip(
        selected: selected,
        onSelected: (_) => onTap(),
        avatar: Icon(icon, size: 18),
        label: Text(label),
      );
}

enum _QrTextPreset { apartment, office, accommodation, vehicle }

extension on _QrTextPreset {
  IconData get icon => switch (this) {
        _QrTextPreset.apartment => Icons.apartment_rounded,
        _QrTextPreset.office => Icons.business_rounded,
        _QrTextPreset.accommodation => Icons.hotel_rounded,
        _QrTextPreset.vehicle => Icons.directions_car_rounded,
      };

  QrPdfTemplate get template => switch (this) {
        _QrTextPreset.apartment => QrPdfTemplate.framed,
        _QrTextPreset.office => QrPdfTemplate.poster,
        _QrTextPreset.accommodation => QrPdfTemplate.poster,
        _QrTextPreset.vehicle => QrPdfTemplate.framed,
      };

  String labelFor(BuildContext context) => switch (this) {
        _QrTextPreset.apartment => context.tr('Apartman', 'Apartment'),
        _QrTextPreset.office => context.tr('Ofis', 'Office'),
        _QrTextPreset.accommodation => context.tr('Konaklama', 'Accommodation'),
        _QrTextPreset.vehicle => context.tr('Araç', 'Vehicle'),
      };

  String topTextFor(BuildContext context) => switch (this) {
        _QrTextPreset.apartment =>
          context.tr('Ziyaretçi misiniz?', 'Are you visiting?'),
        _QrTextPreset.office =>
          context.tr('Ziyaretçi girişi', 'Visitor entrance'),
        _QrTextPreset.accommodation =>
          context.tr('Misafir girişi', 'Guest entrance'),
        _QrTextPreset.vehicle =>
          context.tr('Araç sahibiyle iletişim', 'Contact vehicle owner'),
      };

  String bottomTextFor(BuildContext context) => switch (this) {
        _QrTextPreset.apartment =>
          context.tr('Zili çalmak için taratın', 'Scan to ring the bell'),
        _QrTextPreset.office => context.tr(
            'Yetkiliye ulaşmak için taratın',
            'Scan to contact the door manager',
            'Отсканируйте, чтобы связаться с управляющим дверью'),
        _QrTextPreset.accommodation => context.tr(
            'Kapı yöneticisine ulaşmak için taratın',
            'Scan to contact your door manager',
            'Отсканируйте, чтобы связаться с управляющим дверью'),
        _QrTextPreset.vehicle =>
          context.tr('Bu araç için taratın', 'Scan for this vehicle'),
      };

  String sideTextFor(BuildContext context) => switch (this) {
        _QrTextPreset.apartment => context.tr('Kapı zili', 'Doorbell'),
        _QrTextPreset.office => context.tr('Resepsiyon', 'Reception'),
        _QrTextPreset.accommodation => context.tr('Konaklama', 'Accommodation'),
        _QrTextPreset.vehicle =>
          context.tr('Park / acil durum', 'Parking / urgent'),
      };
}

class _QrTextField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String hint;
  const _QrTextField(
      {required this.controller, required this.label, required this.hint});

  @override
  Widget build(BuildContext context) => TextField(
        controller: controller,
        maxLength: 120,
        textInputAction: TextInputAction.next,
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          suffixIcon: controller.text.trim().isEmpty
              ? null
              : IconButton(
                  tooltip: context.tr('Metni kaldır', 'Remove text'),
                  onPressed: controller.clear,
                  icon: const Icon(Icons.close_rounded)),
        ),
      );
}
