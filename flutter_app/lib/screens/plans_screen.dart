import 'package:flutter/material.dart';

import '../models/door_item.dart';
import '../models/plan_catalog.dart';
import '../ui/app_theme.dart';
import '../widgets/app_shell.dart';

class PlansScreen extends StatelessWidget {
  final PlanItem currentPlan;

  const PlansScreen({super.key, required this.currentPlan});

  @override
  Widget build(BuildContext context) => AppShell(
        title: 'Planlar',
        child: ListView(
          children: [
            _CurrentPlanCard(plan: currentPlan),
            const SizedBox(height: 22),
            const SectionLabel('Planları karşılaştır'),
            const _PlanColumns(),
            const SizedBox(height: 18),
            FilledButton.icon(
              onPressed: currentPlan.isPro && !currentPlan.isTrial
                  ? null
                  : () => _showPurchaseInfo(context),
              icon: const Icon(Icons.workspace_premium_rounded),
              label: Text(currentPlan.isPro && !currentPlan.isTrial
                  ? 'Pro planın aktif'
                  : "Pro'yu Satın Al • ${PlanCatalog.proAnnualPriceLabel}"),
            ),
            const SizedBox(height: 10),
            const Text(
              'Abonelik yıllık yenilenir. Satın alma onayından önce mağaza koşulları ve toplam tutar gösterilir.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.muted, fontSize: 11),
            ),
          ],
        ),
      );

  Future<void> _showPurchaseInfo(BuildContext context) => showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          icon: const Icon(Icons.shopping_bag_outlined,
              color: AppColors.blue, size: 34),
          title: const Text("Pro'yu Satın Al"),
          content: const Text(
            'DOQR Pro yıllık \$14.99 olacak. Güvenli App Store ve Google Play ödeme bağlantısı tamamlandığında satın alma bu ekrandan açılacak.',
            textAlign: TextAlign.center,
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Anladım'),
            ),
          ],
          actionsAlignment: MainAxisAlignment.center,
        ),
      );
}

class _PlanColumns extends StatelessWidget {
  const _PlanColumns();

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
                    subtitle: 'Temel dijital zil özellikleri.',
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
                    price: PlanCatalog.proAnnualPriceLabel,
                    subtitle: 'Görüşme, kurye ve uzun geçmiş.',
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

  const _CurrentPlanCard({required this.plan});

  String get title {
    if (plan.isTrial) return 'Mevcut planın: Pro Deneme';
    if (plan.isPro) return 'Mevcut planın: Pro';
    return 'Mevcut planın: Free';
  }

  String get description {
    if (plan.isTrial) {
      return '3 günlük Pro denemen devam ediyor. Deneme sona erdiğinde hesabın otomatik olarak Free plana geçecek.';
    }
    if (plan.isPro) {
      return 'Pro özelliklerin aktif. Plan ücretin yıllık \$14.99.';
    }
    return "Free planın aktif. Dilediğin zaman yıllık \$14.99 karşılığında Pro'ya geçebilirsin.";
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
                  Text(title,
                      style: Theme.of(context)
                          .textTheme
                          .titleMedium
                          ?.copyWith(color: Colors.white)),
                  const SizedBox(height: 5),
                  Text(description,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.white.withValues(alpha: 0.78))),
                  if (plan.isTrial) ...[
                    const SizedBox(height: 10),
                    const Text(
                      'Deneme hakkı: 30 dk ses • 15 dk görüntü',
                      style: TextStyle(
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
                  Text(feature.title,
                      style: TextStyle(
                          fontSize: compact ? 11 : 14,
                          height: compact ? 1.3 : 1.5,
                          fontWeight: FontWeight.w700)),
                  if (!compact) ...[
                    const SizedBox(height: 2),
                    Text(feature.detail,
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
