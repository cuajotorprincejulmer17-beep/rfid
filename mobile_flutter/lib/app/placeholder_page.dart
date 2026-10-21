import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../core/theme/pulse_theme.dart';
import '../core/theme/pulse_tokens.dart';
import '../shared/widgets/pulse_card.dart';

/// A page that has not been built yet.
///
/// It says so plainly, and the reason is shown, rather than pretending the
/// feature works.
class PlaceholderPage extends StatelessWidget {
  const PlaceholderPage({
    super.key,
    required this.title,
    this.reason = 'Not built yet',
  });

  final String title;
  final String reason;

  @override
  Widget build(BuildContext context) {
    final t = context.pulse;
    return Scaffold(
      backgroundColor: t.background,
      appBar: AppBar(
        backgroundColor: t.background,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          tooltip: 'Back',
          onPressed: () => context.canPop() ? context.pop() : context.go('/home'),
        ),
        title: Text(title, style: PulseType.heading.copyWith(color: t.textPrimary)),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(PulseSpacing.lg),
          child: PulseCard(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.construction_outlined, size: 32, color: t.textSecondary),
                const SizedBox(height: PulseSpacing.md),
                Text(
                  title,
                  style: PulseType.heading.copyWith(color: t.textPrimary),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: PulseSpacing.sm),
                Text(
                  reason,
                  style: PulseType.body.copyWith(color: t.textSecondary),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
