import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../l10n/app_language.dart';
import '../models/door_item.dart';
import '../widgets/app_shell.dart';
import 'plans_screen.dart';

class SettingsScreen extends StatelessWidget {
  final PlanItem plan;
  final Future<void> Function() onDeleteAccount;
  final Future<void> Function() onSignOut;
  const SettingsScreen(
      {super.key,
      required this.plan,
      required this.onDeleteAccount,
      required this.onSignOut});

  Future<void> _openPlans(BuildContext context) async {
    final changed = await Navigator.push<bool>(
      context,
      MaterialPageRoute<bool>(builder: (_) => PlansScreen(currentPlan: plan)),
    );
    if (changed == true && context.mounted) Navigator.pop(context, true);
  }

  Future<void> _chooseLanguage(BuildContext context) async {
    final current = Localizations.localeOf(context).languageCode;
    final selected = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Text('🇹🇷', style: TextStyle(fontSize: 24)),
                title: const Text('Türkçe'),
                trailing:
                    current == 'tr' ? const Icon(Icons.check_rounded) : null,
                onTap: () => Navigator.pop(sheetContext, 'tr'),
              ),
              ListTile(
                leading: const Text('🇬🇧', style: TextStyle(fontSize: 24)),
                title: const Text('English'),
                trailing:
                    current == 'en' ? const Icon(Icons.check_rounded) : null,
                onTap: () => Navigator.pop(sheetContext, 'en'),
              ),
            ],
          ),
        ),
      ),
    );
    if (selected != null && context.mounted) {
      await AppLanguageScope.of(context).setLocale(Locale(selected));
    }
  }

  @override
  Widget build(BuildContext context) => AppShell(
        title: context.tr('Ayarlar', 'Settings'),
        child: ListView(
          children: [
            ListTile(
              leading: const Icon(Icons.workspace_premium_outlined),
              title:
                  Text(context.tr('Plan ve abonelik', 'Plan and subscription')),
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
              leading: const Icon(Icons.language_rounded),
              title: Text(context.tr('Dil', 'Language')),
              subtitle: Text(context.isEnglish ? 'English' : 'Türkçe'),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () => _chooseLanguage(context),
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
              leading: const Icon(Icons.logout_rounded),
              title: Text(context.tr('Çıkış yap', 'Sign out')),
              onTap: onSignOut,
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
