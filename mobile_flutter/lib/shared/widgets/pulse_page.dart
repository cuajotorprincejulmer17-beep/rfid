import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/pulse_theme.dart';
import '../../core/theme/pulse_tokens.dart';

/// A page that is pushed on the root navigator.
///
/// It has no dock and no launcher, because the shell is not rendered
/// underneath it. Its app bar holds local controls only: Back, and whatever
/// the page itself needs. There is never a Profile, Settings, More, bell,
/// avatar, gear or hamburger in a corner, and never a floating action
/// button.
class PulsePage extends StatelessWidget {
  const PulsePage({
    super.key,
    required this.title,
    required this.child,
    this.actions = const <Widget>[],
    this.subtitle,
    this.scrollable = true,
    this.padding = const EdgeInsets.fromLTRB(
      PulseSpacing.lg,
      0,
      PulseSpacing.lg,
      PulseSpacing.xxl,
    ),
  });

  final String title;
  final Widget child;

  /// Local controls for this page only.
  final List<Widget> actions;

  final String? subtitle;
  final bool scrollable;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final t = context.pulse;

    final body = scrollable
        ? SingleChildScrollView(
            padding: padding,
            child: child,
          )
        : Padding(padding: padding, child: child);

    return Scaffold(
      backgroundColor: t.background,
      appBar: AppBar(
        backgroundColor: t.background,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          tooltip: 'Back',
          onPressed: () =>
              context.canPop() ? context.pop() : context.go('/home'),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              title,
              style: PulseType.heading.copyWith(color: t.textPrimary),
            ),
            if (subtitle != null)
              Text(
                subtitle!,
                style: PulseType.caption.copyWith(color: t.textSecondary),
              ),
          ],
        ),
        actions: actions,
      ),
      body: body,
    );
  }
}

/// A label that marks a region as showing sample rather than school data.
class SampleDataChip extends StatelessWidget {
  const SampleDataChip({super.key});

  @override
  Widget build(BuildContext context) {
    final t = context.pulse;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: PulseSpacing.sm,
        vertical: PulseSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: t.warning.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(PulseRadius.input),
        border: Border.all(color: t.warning.withValues(alpha: 0.45)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.science_outlined, size: 14, color: t.warning),
          const SizedBox(width: PulseSpacing.xs),
          Text(
            'Sample data',
            style: PulseType.caption.copyWith(color: t.warning),
          ),
        ],
      ),
    );
  }
}
