import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../widgets/app_shell.dart';

class DoorQrScreen extends StatelessWidget {
  final String doorLabel;
  final String qrUrl;
  final String tokenId;

  const DoorQrScreen({super.key, required this.doorLabel, required this.qrUrl, required this.tokenId});

  @override
  Widget build(BuildContext context) {
    return AppShell(
      title: 'QR • $doorLabel',
      child: ListView(
        children: [
          ElevCard(
            child: Column(
              children: [
                QrImageView(data: qrUrl, version: QrVersions.auto, size: 250),
                const SizedBox(height: 14),
                const Align(alignment: Alignment.centerLeft, child: Text('QR Linki')),
                SelectableText(qrUrl),
                const SizedBox(height: 8),
                const Align(alignment: Alignment.centerLeft, child: Text('Token ID')),
                SelectableText(tokenId),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
