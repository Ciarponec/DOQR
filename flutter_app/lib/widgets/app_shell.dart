import 'package:flutter/material.dart';

class AppShell extends StatelessWidget {
  final String title;
  final List<Widget>? actions;
  final Widget child;
  final bool safeBottom;

  const AppShell({super.key, required this.title, required this.child, this.actions, this.safeBottom = true});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title), actions: actions),
      body: SafeArea(
        bottom: safeBottom,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: child,
        ),
      ),
    );
  }
}

class ElevCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  const ElevCard({super.key, required this.child, this.padding = const EdgeInsets.all(14)});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: const [
          BoxShadow(color: Color(0x1A0F172A), blurRadius: 20, offset: Offset(0, 8)),
        ],
      ),
      padding: padding,
      child: child,
    );
  }
}

class SectionLabel extends StatelessWidget {
  final String text;
  const SectionLabel(this.text, {super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(text, style: Theme.of(context).textTheme.titleMedium),
    );
  }
}
