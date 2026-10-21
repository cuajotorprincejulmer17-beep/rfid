import 'package:flutter/material.dart';

import '../../core/theme/pulse_theme.dart';
import '../../core/theme/pulse_tokens.dart';
import 'pulse_button.dart';

/// The state a data region is in.
///
/// A network failure is never rendered as "absent" or "zero": it is
/// [error], and it carries a Retry.
enum PulseStateKind { loading, empty, error, offline, permissionDenied }

/// The full set of states a data region can be in.
class PulseState {
  const PulseState._({
    required this.kind,
    this.message,
    this.actionLabel,
    this.onAction,
    this.title,
  });

  const PulseState.loading() : this._(kind: PulseStateKind.loading);

  /// The server confirmed there is nothing to show.
  const PulseState.empty({
    String? message,
    String? actionLabel,
    VoidCallback? onAction,
    String? title,
  }) : this._(
          kind: PulseStateKind.empty,
          message: message,
          actionLabel: actionLabel,
          onAction: onAction,
          title: title,
        );

  /// The request failed. The data is unknown, not absent.
  const PulseState.error({
    String? message,
    String? actionLabel,
    VoidCallback? onAction,
    String? title,
  }) : this._(
          kind: PulseStateKind.error,
          message: message,
          actionLabel: actionLabel,
          onAction: onAction,
          title: title,
        );

  /// The device is offline. Cached data may still be shown.
  const PulseState.offline({
    String? message,
    String? actionLabel,
    VoidCallback? onAction,
    String? title,
  }) : this._(
          kind: PulseStateKind.offline,
          message: message,
          actionLabel: actionLabel,
          onAction: onAction,
          title: title,
        );

  /// The student did not grant the permission this feature needs.
  const PulseState.permissionDenied({
    String? message,
    String? actionLabel,
    VoidCallback? onAction,
    String? title,
  }) : this._(
          kind: PulseStateKind.permissionDenied,
          message: message,
          actionLabel: actionLabel,
          onAction: onAction,
          title: title,
        );

  final PulseStateKind kind;
  final String? message;
  final String? actionLabel;
  final VoidCallback? onAction;

  /// Overrides the default title for this state.
  final String? title;
}

/// A full-region placeholder for a data state.
///
/// Empty states carry a next action; error and offline states carry Retry.
class StateView extends StatelessWidget {
  const StateView({
    super.key,
    required this.state,
    this.compact = false,
  });

  final PulseState state;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final t = context.pulse;

    final (IconData icon, String defaultTitle, Color color) = switch (state.kind) {
      PulseStateKind.loading => (
          Icons.hourglass_empty_rounded,
          'Loading',
          t.textSecondary,
        ),
      PulseStateKind.empty => (
          Icons.inbox_outlined,
          'Nothing here yet',
          t.textSecondary,
        ),
      PulseStateKind.error => (
          Icons.error_outline,
          'Could not load this',
          t.error,
        ),
      PulseStateKind.offline => (
          Icons.wifi_off_rounded,
          "You're offline",
          t.warning,
        ),
      PulseStateKind.permissionDenied => (
          Icons.lock_outline,
          'Permission needed',
          t.warning,
        ),
    };

    final title = state.title ?? defaultTitle;

    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: PulseSpacing.lg,
        vertical: compact ? PulseSpacing.md : PulseSpacing.xl,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: compact ? 28 : 36, color: color),
          const SizedBox(height: PulseSpacing.sm),
          Text(
            title,
            textAlign: TextAlign.center,
            style: PulseType.label.copyWith(color: t.textPrimary),
          ),
          if (state.message != null) ...[
            const SizedBox(height: PulseSpacing.xs),
            Text(
              state.message!,
              textAlign: TextAlign.center,
              style: PulseType.caption.copyWith(color: t.textSecondary),
            ),
          ],
          if (state.actionLabel != null && state.onAction != null) ...[
            const SizedBox(height: PulseSpacing.md),
            PulseButton(
              label: state.actionLabel!,
              onPressed: state.onAction,
              variant: PulseButtonVariant.secondary,
              expanded: false,
            ),
          ],
        ],
      ),
    );
  }
}
