import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/session.dart';

import '../../core/accessibility/motion_preferences.dart';
import '../../core/theme/pulse_theme.dart';
import '../../core/theme/pulse_tokens.dart';
import '../../core/theme/theme_controller.dart';
import '../auth/server_address_card.dart';
import '../../shared/repositories/repository_providers.dart';
import '../../shared/repositories/repositories.dart';
import '../../shared/widgets/pulse_button.dart';
import '../../shared/widgets/pulse_card.dart';
import '../../shared/widgets/pulse_chip.dart';
import '../../shared/widgets/pulse_page.dart';

/// The Profile page.
///
/// The profile is read-only apart from a display name the student edits
/// themselves. There is no avatar control in the top corner.
class ProfilePage extends ConsumerStatefulWidget {
  const ProfilePage({
    super.key,
    required this.name,
    required this.studentNumber,
    this.courseSection,
    this.phone,
    this.rfidRegistered,
  });

  final String name;
  final String studentNumber;
  final String? courseSection;
  final String? phone;

  /// Whether the school registered an RFID card for this student.
  final bool? rfidRegistered;

  @override
  ConsumerState<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends ConsumerState<ProfilePage> {
  String? _displayName;

  @override
  Widget build(BuildContext context) {
    final t = context.pulse;
    final name = _displayName ?? widget.name;

    return PulsePage(
      title: 'Profile',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PulseCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        color: t.softFill,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: t.primary.withValues(alpha: 0.5),
                        ),
                      ),
                      child: Icon(
                        Icons.person_outline,
                        size: 28,
                        color: t.navSelected,
                      ),
                    ),
                    const SizedBox(width: PulseSpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            name,
                            style: PulseType.heading.copyWith(color: t.textPrimary),
                          ),
                          Text(
                            widget.studentNumber,
                            style: PulseType.caption
                                .copyWith(color: t.textSecondary),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: PulseSpacing.lg),
                _Row(label: 'Course section', value: widget.courseSection),
                _Row(label: 'Phone', value: widget.phone),
                if (widget.rfidRegistered != null)
                  _Row(
                    label: 'RFID card',
                    value: widget.rfidRegistered! ? 'Registered' : 'Not registered',
                  ),
                const SizedBox(height: PulseSpacing.md),
                Text(
                  'Edit display name',
                  style: PulseType.label.copyWith(color: t.textSecondary),
                ),
                const SizedBox(height: PulseSpacing.sm),
                Wrap(
                  spacing: PulseSpacing.sm,
                  children: [
                    for (final suggestion in const ['Student', 'Intern', 'Delegate'])
                      PulseChip(
                        label: suggestion,
                        selected: name == suggestion,
                        onSelected: () => setState(() => _displayName = suggestion),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// A label and value row on the profile card.
class _Row extends StatelessWidget {
  const _Row({required this.label, required this.value});

  final String label;
  final String? value;

  @override
  Widget build(BuildContext context) {
    final t = context.pulse;
    return Padding(
      padding: const EdgeInsets.only(bottom: PulseSpacing.sm),
      child: Row(
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: PulseType.caption.copyWith(color: t.textSecondary),
            ),
          ),
          Expanded(
            child: Text(
              value ?? 'Not provided',
              style: PulseType.body.copyWith(color: t.textPrimary),
            ),
          ),
        ],
      ),
    );
  }
}

/// The Appearance page.
///
/// The theme, the reduce-motion setting and the haptics setting live here
/// and nowhere else.
class AppearancePage extends ConsumerWidget {
  const AppearancePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.pulse;
    final theme = ref.watch(themeControllerProvider);
    final reduceMotion = ref.watch(reduceMotionControllerProvider);
    final haptics = ref.watch(hapticsControllerProvider);

    return PulsePage(
      title: 'Appearance',
      subtitle: 'How Pulse looks and feels',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Theme',
            style: PulseType.heading.copyWith(color: t.textPrimary),
          ),
          const SizedBox(height: PulseSpacing.md),
          for (final option in PulseThemeName.values)
            Padding(
              padding: const EdgeInsets.only(bottom: PulseSpacing.md),
              child: PulseCard(
                onTap: () =>
                    ref.read(themeControllerProvider.notifier).setTheme(option),
                child: Row(
                  children: [
                    _ThemePreview(tokens: option.tokens),
                    const SizedBox(width: PulseSpacing.md),
                    Expanded(
                      child: Text(
                        option.label,
                        style: PulseType.body.copyWith(color: t.textPrimary),
                      ),
                    ),
                    if (theme == option)
                      Icon(Icons.check_circle_rounded, size: 20, color: t.success),
                  ],
                ),
              ),
            ),

          const SizedBox(height: PulseSpacing.lg),

          Text(
            'Motion',
            style: PulseType.heading.copyWith(color: t.textPrimary),
          ),
          const SizedBox(height: PulseSpacing.md),
          Wrap(
            spacing: PulseSpacing.sm,
            runSpacing: PulseSpacing.sm,
            children: [
              for (final option in ReduceMotionSetting.values)
                PulseChip(
                  label: option.label,
                  selected: reduceMotion == option,
                  onSelected: () => ref
                      .read(reduceMotionControllerProvider.notifier)
                      .setSetting(option),
                ),
            ],
          ),
          const SizedBox(height: PulseSpacing.sm),
          Text(
            'Reduce motion removes movement and scaling. The system setting is '
            'always respected.',
            style: PulseType.caption.copyWith(color: t.textSecondary),
          ),

          const SizedBox(height: PulseSpacing.lg),

          PulseCard(
            onTap: () => ref
                .read(hapticsControllerProvider.notifier)
                .setEnabled(!haptics),
            child: Row(
              children: [
                Icon(
                  haptics
                      ? Icons.vibration_rounded
                      : Icons.smartphone_rounded,
                  size: 20,
                  color: t.textSecondary,
                ),
                const SizedBox(width: PulseSpacing.md),
                Expanded(
                  child: Text(
                    'Haptic feedback',
                    style: PulseType.body.copyWith(color: t.textPrimary),
                  ),
                ),
                Text(
                  haptics ? 'On' : 'Off',
                  style: PulseType.label.copyWith(
                    color: haptics ? t.success : t.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// A small preview of a theme's colours.
class _ThemePreview extends StatelessWidget {
  const _ThemePreview({required this.tokens});

  final PulseTokens tokens;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: tokens.background,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: tokens.border),
      ),
      child: Center(
        child: Container(
          width: 16,
          height: 16,
          decoration: BoxDecoration(
            color: tokens.primary,
            shape: BoxShape.circle,
          ),
        ),
      ),
    );
  }
}

/// The Settings page.
class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.pulse;
    final scenario = ref.watch(demoScenarioProvider);
    final auth = ref.watch(authControllerProvider);
    // Watched so the page rebuilds when the student signs in or out.
    ref.watch(authStatusProvider);

    return PulsePage(
      title: 'Settings',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (auth != null) ...[
            Text(
              'School account',
              style: PulseType.heading.copyWith(color: t.textPrimary),
            ),
            const SizedBox(height: PulseSpacing.md),
            const ServerAddressCard(),
            if (auth.isSignedIn) ...[
              const SizedBox(height: PulseSpacing.md),
              PulseButton(
                label: 'Sign out',
                icon: Icons.logout_rounded,
                variant: PulseButtonVariant.secondary,
                onPressed: auth.signOut,
              ),
            ],
            const SizedBox(height: PulseSpacing.xl),
          ],
          if (ref.watch(usingSampleDataProvider)) ...[
          Text(
            'Sample data scenario',
            style: PulseType.heading.copyWith(color: t.textPrimary),
          ),
          const SizedBox(height: PulseSpacing.xs),
          Text(
            'The features the school backend does not serve yet are backed by '
            'sample data. Change the scenario to see how each state looks.',
            style: PulseType.caption.copyWith(color: t.textSecondary),
          ),
          const SizedBox(height: PulseSpacing.md),
          Wrap(
            spacing: PulseSpacing.sm,
            runSpacing: PulseSpacing.sm,
            children: [
              for (final option in DemoScenario.values)
                PulseChip(
                  label: option.label,
                  selected: scenario == option,
                  onSelected: () => ref
                      .read(demoScenarioProvider.notifier)
                      .setScenario(option),
                ),
            ],
          ),
          const SizedBox(height: PulseSpacing.sm),
          Text(
            scenario.description,
            style: PulseType.caption.copyWith(color: t.textSecondary),
          ),
          ],

          const SizedBox(height: PulseSpacing.xl),

          Text(
            'About',
            style: PulseType.heading.copyWith(color: t.textPrimary),
          ),
          const SizedBox(height: PulseSpacing.md),
          PulseCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Pulse',
                  style: PulseType.body.copyWith(color: t.textPrimary),
                ),
                const SizedBox(height: PulseSpacing.xs),
                Text(
                  'Version 1.0.0',
                  style: PulseType.caption.copyWith(color: t.textSecondary),
                ),
                const SizedBox(height: PulseSpacing.md),
                Text(
                  'Attendance is read-only and comes from the school server. '
                  'Signed in, tasks, schedules and campus information also come '
                  'from the school server. '
                  'No biometric, campus security or emergency integration is '
                  'claimed anywhere in this app.',
                  style: PulseType.caption.copyWith(color: t.textSecondary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
