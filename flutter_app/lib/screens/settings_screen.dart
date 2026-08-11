import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../l10n/app_language.dart';
import '../models/door_item.dart';
import '../widgets/app_shell.dart';
import 'plans_screen.dart';

class SettingsScreen extends StatelessWidget {
  final PlanItem plan;
  final Future<void> Function() onDeleteAccount;
  const SettingsScreen(
      {super.key, required this.plan, required this.onDeleteAccount});

  Future<void> _openPlans(BuildContext context) async {
    final changed = await Navigator.push<bool>(
      context,
      MaterialPageRoute<bool>(builder: (_) => PlansScreen(currentPlan: plan)),
    );
    if (changed == true && context.mounted) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) => AppShell(
        title: context.tr('Ayarlar', 'Settings'),
        child: ListView(
          children: [
            ListTile(
              leading: const Icon(Icons.workspace_premium_outlined),
              title: Text(context.tr('Plan ve abonelik', 'Plan and subscription')),
              subtitle: Text(plan.isTrial
                  ? context.tr('Pro deneme aktif', 'Pro trial active')
                  : plan.isPro
                      ? 'Pro'
                      : 'Free'),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () => _openPlans(context),
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.privacy_tip_outlined),
              title: Text(context.tr('Gizlilik bildirimi', 'Privacy notice')),
              trailing: const Icon(Icons.open_in_new_rounded, size: 18),
              onTap: () => launchUrl(
                Uri.parse(context.isEnglish
                    ? 'https://ciarponec.github.io/DOQR/privacy-en.html'
                    : 'https://ciarponec.github.io/DOQR/privacy.html'),
                mode: LaunchMode.externalApplication,
              ),
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.delete_forever_outlined,
                  color: Color(0xFFE54867)),
              title: Text(context.tr('Hesabımı sil', 'Delete my account'),
                  style: const TextStyle(color: Color(0xFFE54867))),
              onTap: onDeleteAccount,
            ),
          ],
        ),
      );
}
