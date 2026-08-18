import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../l10n/app_language.dart';
import '../models/door_item.dart';
import '../models/plan_catalog.dart';
import '../services/store_purchase_service.dart';
import '../ui/app_theme.dart';
import '../widgets/app_shell.dart';

class PlansScreen extends StatefulWidget {
  final PlanItem currentPlan;

  const PlansScreen({super.key, required this.currentPlan});

  @override
  State<PlansScreen> createState() => _PlansScreenState();
}

class _PlansScreenState extends State<PlansScreen> {
  static final _termsUrl = Uri.parse(
      'https://www.apple.com/legal/internet-services/itunes/dev/stdeula/');
  static final _manageSubscriptionsUrl =
      Uri.parse('https://apps.apple.com/account/subscriptions');

  final _store = StorePurchaseService.instance;
  bool _handlingSuccess = false;

  @override
  void initState() {
    super.initState();
    _store.addListener(_onStoreChanged);
    _store.initialize();
  }

  @override
  void dispose() {
    _store.removeListener(_onStoreChanged);
    super.dispose();
  }

  void _onStoreChanged() {
    if (mounted) setState(() {});
    if (!_handlingSuccess && _store.takeEntitlementActivated()) {
      _handlingSuccess = true;
      Future.microtask(() {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(context.tr('DOQR Pro hesabında etkinleştirildi.',
                  'DOQR Pro has been activated on your account.'))),
        );
        Navigator.of(context).pop(true);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    _store.setLocale(Localizations.localeOf(context));
    return AppShell(
      title: context.tr('Planlar', 'Plans'),
      child: ListView(
        children: [
          _CurrentPlanCard(
            plan: widget.currentPlan,
            proPrice: _store.displayPrice,
          ),
          const SizedBox(height: 22),
          SectionLabel(context.tr('Planları karşılaştır', 'Compare plans')),
          _PlanColumns(proPrice: _store.displayPrice),
          const SizedBox(height: 18),
          _SubscriptionOfferCard(price: _store.displayPrice),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: widget.currentPlan.isPro && !widget.currentPlan.isTrial
                ? null
                : (_store.processing ? null : _store.buyPro),
            icon: const Icon(Icons.workspace_premium_rounded),
            label: Text(widget.currentPlan.isPro && !widget.currentPlan.isTrial
                ? context.tr('Pro planın aktif', 'Your Pro plan is active')
                : _store.processing
                    ? context.tr('Mağaza onayı bekleniyor…',
                        'Waiting for store approval…')
                    : context.tr(
                        "Pro'yu Satın Al • ${_store.displayPrice} / yıl",
                        'Buy Pro • ${_store.displayPrice} / year')),
          ),
          if (_store.loading) ...[
            const SizedBox(height: 10),
            const LinearProgressIndicator(),
          ],
          if (_store.error != null) ...[
            const SizedBox(height: 10),
            Text(
              _store.error!,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.danger, fontSize: 12),
            ),
          ],
          TextButton(
            onPressed: _store.processing ? null : _store.restorePurchases,
            child: Text(
                context.tr('Satın almayı geri yükle', 'Restore purchases')),
          ),
          const SizedBox(height: 10),
          Text(
            context.tr(
                'DOQR Pro yıllık ve otomatik yenilenen bir aboneliktir. Ücret, mağaza hesabınızdan tahsil edilir. Yenilemeyi Google Play veya App Store abonelik ayarlarından istediğiniz zaman iptal edebilirsiniz; ödenmiş dönem sonuna kadar Pro erişiminiz sürer.',
                'DOQR Pro is an annual, auto-renewing subscription. Payment is charged to your store account. You can cancel renewal at any time in your Google Play or App Store subscription settings; Pro access continues through the paid period.'),
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.muted, fontSize: 11),
          ),
          const SizedBox(height: 6),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 4,
            children: [
              TextButton(
                onPressed: () => launchUrl(
                  Uri.parse(context.isEnglish
                      ? 'https://ciarponec.github.io/DOQR/privacy-en.html'
                      : 'https://ciarponec.github.io/DOQR/privacy.html'),
                  mode: LaunchMode.externalApplication,
                ),
                child:
                    Text(context.tr('Gizlilik Politikası', 'Privacy Policy')),
              ),
              TextButton(
                onPressed: () => launchUrl(
                  _termsUrl,
                  mode: LaunchMode.externalApplication,
                ),
                child: Text(context.tr('Kullanım Koşulları', 'Terms of Use')),
              ),
              if (defaultTargetPlatform == TargetPlatform.iOS)
                TextButton(
                  onPressed: () => launchUrl(
                    _manageSubscriptionsUrl,
                    mode: LaunchMode.externalApplication,
                  ),
                  child: Text(
                      context.tr('Aboneliği Yönet', 'Manage Subscription')),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SubscriptionOfferCard extends StatelessWidget {
  final String price;

  const _SubscriptionOfferCard({required this.price});

  @override
  Widget build(BuildContext context) => ElevCard(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              context.tr('DOQR Pro Yıllık', 'DOQR Pro Annual'),
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 6),
            Text(
              context.tr('Süre: 1 yıl • Fiyat: $price / yıl',
                  'Length: 1 year • Price: $price / year'),
            ),
            const SizedBox(height: 4),
            Text(
              context.tr(
                  'Otomatik yenilenir; yenileme abonelik ayarlarından iptal edilebilir.',
                  'Auto-renews; renewal can be canceled in subscription settings.'),
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: AppColors.muted),
            ),
          ],
        ),
      );
}

class _PlanColumns extends StatelessWidget {
  final String proPrice;

  const _PlanColumns({required this.proPrice});

  @override
  Widget build(BuildContext context) => LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 620;
          return IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: _PlanCard(
                    title: 'Free',
                    price: r'$0',
                    subtitle: context.tr('Temel dijital zil özellikleri.',
                        'Essential digital doorbell features.'),
                    icon: Icons.qr_code_2_rounded,
                    accent: AppColors.blue,
                    features: PlanCatalog.freeFeatures,
                    compact: compact,
                  ),
                ),
                SizedBox(width: compact ? 9 : 14),
                Expanded(
                  child: _PlanCard(
                    title: 'Pro',
                    price: context.tr('$proPrice / yıl', '$proPrice / year'),
                    subtitle: context.tr('Görüşme, kurye ve uzun geçmiş.',
                        'Calling, courier tools, and extended history.'),
                    icon: Icons.workspace_premium_rounded,
                    accent: AppColors.warning,
                    features: PlanCatalog.proFeatures,
                    highlighted: true,
                    compact: compact,
                  ),
                ),
              ],
            ),
          );
        },
      );
}

class _CurrentPlanCard extends StatelessWidget {
  final PlanItem plan;
  final String proPrice;

  const _CurrentPlanCard({required this.plan, required this.proPrice});

  String title(BuildContext context) {
    if (plan.isTrial) {
      return context.tr('Mevcut planın: Pro Deneme', 'Current plan: Pro Trial');
    }
    if (plan.isPro) {
      return context.tr('Mevcut planın: Pro', 'Current plan: Pro');
    }
    return context.tr('Mevcut planın: Free', 'Current plan: Free');
  }

  String description(BuildContext context) {
    if (plan.isTrial) {
      return context.tr(
          '3 günlük Pro denemen devam ediyor. Deneme sona erdiğinde hesabın otomatik olarak Free plana geçecek.',
          'Your 3-day Pro trial is active. Your account will automatically switch to Free when it ends.');
    }
    if (plan.isPro) {
      return context.tr(
          'Pro özelliklerin aktif. Aboneliğini mağaza hesabından yönetebilirsin.',
          'Your Pro features are active. You can manage the subscription from your store account.');
    }
    return context.tr(
        "Free planın aktif. Dilediğin zaman yıllık $proPrice karşılığında Pro'ya geçebilirsin.",
        'Your Free plan is active. You can upgrade to Pro for $proPrice per year at any time.');
  }

  @override
  Widget build(BuildContext context) => ElevCard(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.navy, Color(0xFF253D88)],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Icon(Icons.workspace_premium_rounded,
                  color: Colors.white),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title(context),
                      style: Theme.of(context)
                          .textTheme
                          .titleMedium
                          ?.copyWith(color: Colors.white)),
                  const SizedBox(height: 5),
                  Text(description(context),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.white.withValues(alpha: 0.78))),
                  if (plan.isTrial) ...[
                    const SizedBox(height: 10),
                    Text(
                      context.tr('Deneme hakkı: 30 dk ses • 15 dk görüntü',
                          'Trial allowance: 30 min audio • 15 min video'),
                      style: const TextStyle(
                          color: Color(0xFFB9F4FF),
                          fontSize: 11,
                          fontWeight: FontWeight.w700),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      );
}

class _PlanCard extends StatelessWidget {
  final String title;
  final String price;
  final String subtitle;
  final IconData icon;
  final Color accent;
  final List<PlanFeature> features;
  final bool highlighted;
  final bool compact;

  const _PlanCard({
    required this.title,
    required this.price,
    required this.subtitle,
    required this.icon,
    required this.accent,
    required this.features,
    this.highlighted = false,
    required this.compact,
  });

  @override
  Widget build(BuildContext context) => ElevCard(
        color: highlighted ? const Color(0xFFFFFCF3) : Colors.white,
        padding: EdgeInsets.all(compact ? 12 : 18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SoftIcon(icon, color: accent, size: compact ? 38 : 48),
            SizedBox(height: compact ? 9 : 13),
            Text(title,
                style: compact
                    ? Theme.of(context).textTheme.titleMedium
                    : Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 2),
            Text(
              price,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: highlighted ? AppColors.blue : AppColors.ink),
            ),
            if (!compact) ...[
              const SizedBox(height: 4),
              Text(subtitle,
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: AppColors.muted)),
            ],
            SizedBox(height: compact ? 14 : 18),
            ...features.map(
              (feature) => _FeatureRow(feature: feature, compact: compact),
            ),
          ],
        ),
      );
}

class _FeatureRow extends StatelessWidget {
  final PlanFeature feature;
  final bool compact;

  const _FeatureRow({required this.feature, required this.compact});

  @override
  Widget build(BuildContext context) => Padding(
        padding: EdgeInsets.only(bottom: compact ? 11 : 14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Icon(Icons.check_circle_rounded,
                  size: compact ? 16 : 20, color: AppColors.success),
            ),
            SizedBox(width: compact ? 6 : 11),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(feature.titleFor(context.isEnglish),
                      style: TextStyle(
                          fontSize: compact ? 11 : 14,
                          height: compact ? 1.3 : 1.5,
                          fontWeight: FontWeight.w700)),
                  if (!compact) ...[
                    const SizedBox(height: 2),
                    Text(feature.detailFor(context.isEnglish),
                        style: Theme.of(context)
                            .textTheme
                            .bodySmall
                            ?.copyWith(color: AppColors.muted)),
                  ],
                ],
              ),
            ),
          ],
        ),
      );
}
