import 'package:flutter/material.dart';

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
          const SnackBar(content: Text('DOQR Pro hesabında etkinleştirildi.')),
        );
        Navigator.of(context).pop(true);
      });
    }
  }

  @override
  Widget build(BuildContext context) => AppShell(
        title: 'Planlar',
        child: ListView(
          children: [
            _CurrentPlanCard(plan: widget.currentPlan),
            const SizedBox(height: 22),
            const SectionLabel('Planları karşılaştır'),
            _PlanColumns(proPrice: _store.displayPrice),
            const SizedBox(height: 18),
            FilledButton.icon(
              onPressed: widget.currentPlan.isPro && !widget.currentPlan.isTrial
                  ? null
                  : (_store.processing ? null : _store.buyPro),
              icon: const Icon(Icons.workspace_premium_rounded),
              label:
                  Text(widget.currentPlan.isPro && !widget.currentPlan.isTrial
                      ? 'Pro planın aktif'
                      : _store.processing
                          ? 'Mağaza onayı bekleniyor…'
                          : "Pro'yu Satın Al • ${_store.displayPrice} / yıl"),
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
              child: const Text('Satın almayı geri yükle'),
            ),
            const SizedBox(height: 10),
            const Text(
              'DOQR Pro yıllık ve otomatik yenilenen bir aboneliktir. Ücret, mağaza hesabınızdan tahsil edilir. Yenilemeyi Google Play veya App Store abonelik ayarlarından istediğiniz zaman iptal edebilirsiniz; ödenmiş dönem sonuna kadar Pro erişiminiz sürer.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.muted, fontSize: 11),
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
                    price: '$proPrice / yıl',
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
