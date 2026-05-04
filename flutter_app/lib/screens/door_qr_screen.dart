import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

class DoorQrScreen extends StatelessWidget {
  final String doorLabel;
  final String qrUrl;
  final String tokenId;

  const DoorQrScreen({super.key, required this.doorLabel, required this.qrUrl, required this.tokenId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('QR - $doorLabel')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            QrImageView(data: qrUrl, version: QrVersions.auto, size: 260),
            const SizedBox(height: 16),
            const Text('QR Linki'),
            SelectableText(qrUrl),
            const SizedBox(height: 8),
            const Text('Token ID'),
            SelectableText(tokenId),
          ],
        ),
      ),
    );
  }
}
