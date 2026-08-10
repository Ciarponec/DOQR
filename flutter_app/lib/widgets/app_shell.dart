import 'package:flutter/material.dart';

import '../l10n/app_language.dart';
import '../ui/app_theme.dart';

class AppShell extends StatelessWidget {
  final String title;
  final List<Widget>? actions;
  final Widget child;
  final bool safeBottom;
  final bool showAppBar;

  const AppShell({
    super.key,
    required this.title,
    required this.child,
    this.actions,
    this.safeBottom = true,
    this.showAppBar = true,
  });

  @override
  Widget build(BuildContext context) => Scaffold(
        extendBodyBehindAppBar: !showAppBar,
        appBar: showAppBar
            ? AppBar(
                title: Text(title),
                actions: [
                  const LanguagePickerButton(),
                  ...?actions,
                ],
                toolbarHeight: 72,
                actionsPadding: const EdgeInsets.only(right: 12),
              )
            : null,
        body: DecoratedBox(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFFFAFBFF), AppColors.mist],
              stops: [0, 0.55],
            ),
          ),
          child: SafeArea(
            top: !showAppBar,
            bottom: safeBottom,
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 760),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(18, 8, 18, 18),
                  child: child,
                ),
              ),
            ),
          ),
        ),
      );
}

class ElevCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color color;
  final Gradient? gradient;
  final VoidCallback? onTap;

  const ElevCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(18),
    this.color = Colors.white,
    this.gradient,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final content = Container(
      decoration: BoxDecoration(
        color: gradient == null ? color : null,
        gradient: gradient,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
            color: gradient == null
                ? AppColors.line.withValues(alpha: 0.85)
                : Colors.transparent),
        boxShadow: const [
          BoxShadow(
              color: Color(0x0D111936), blurRadius: 30, offset: Offset(0, 12)),
          BoxShadow(
              color: Color(0x080B1020), blurRadius: 8, offset: Offset(0, 2)),
        ],
      ),
      padding: padding,
      child: child,
    );
    if (onTap == null) return content;
    return Material(
      color: Colors.transparent,
      child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(24),
          child: content),
    );
  }
}

class SectionLabel extends StatelessWidget {
  final String text;
  const SectionLabel(this.text, {super.key});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(left: 2, bottom: 10),
        child: Text(text, style: Theme.of(context).textTheme.titleLarge),
      );
}

class SoftIcon extends StatelessWidget {
  final IconData icon;
  final Color color;
  final double size;
  const SoftIcon(this.icon,
      {super.key, this.color = AppColors.blue, this.size = 48});

  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
            color: color.withValues(alpha: 0.11),
            borderRadius: BorderRadius.circular(size * 0.32)),
        child: Icon(icon, color: color, size: size * 0.5),
      );
}
