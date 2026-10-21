import 'package:flutter/material.dart';

import '../../core/state/pulse_data.dart';
import '../../core/theme/pulse_theme.dart';
import '../../core/theme/pulse_tokens.dart';
import 'pulse_skeleton.dart';
import 'state_view.dart';

/// Bridges a [PulseData] to the six data states.
///
/// The rules it enforces come straight from the backend contract:
///  * a failure shows "Status unknown" and a Retry, never an empty message,
///  * only a successful response may show the empty state,
///  * a cached value is labelled as a saved copy,
///  * a fresh value is labelled with its update time.
class PulseDataStateView<T> extends StatelessWidget {
  const PulseDataStateView({
    super.key,
    required this.data,
    required this.builder,
    this.onRetry,
    this.emptyTitle,
    this.emptyBody,
    this.emptyActionLabel,
    this.onEmptyAction,
    this.errorMessage,
  });

  final PulseData<T> data;
  final Widget Function(BuildContext context, T value, Widget? freshness) builder;
  final VoidCallback? onRetry;
  final String? emptyTitle;
  final String? emptyBody;
  final String? emptyActionLabel;
  final VoidCallback? onEmptyAction;
  final String? errorMessage;

  @override
  Widget build(BuildContext context) {
    final t = context.pulse;

    switch (data.status) {
      case PulseDataStatus.idle:
      case PulseDataStatus.loading:
        return const PulseSkeletonList();

      case PulseDataStatus.error:
        return StateView(
          state: PulseState.error(
            title: 'Status unknown',
            message: errorMessage ??
                'The server did not answer, so this status is unknown.',
            actionLabel: onRetry == null ? null : 'Retry',
            onAction: onRetry,
          ),
        );

      case PulseDataStatus.empty:
        return StateView(
          state: PulseState.empty(
            title: emptyTitle ?? 'Nothing here yet',
            message: emptyBody,
            actionLabel: emptyActionLabel,
            onAction: onEmptyAction,
          ),
        );

      case PulseDataStatus.fresh:
      case PulseDataStatus.cached:
        final value = data.value;
        if (value == null) {
          return StateView(
            state: PulseState.empty(
              title: emptyTitle ?? 'Nothing here yet',
              message: emptyBody,
              actionLabel: emptyActionLabel,
              onAction: onEmptyAction,
            ),
          );
        }

        // The builder decides where the freshness line goes; it is passed in
        // so the caller can place it next to the content it describes.
        final freshness = _freshness(context, t);
        return builder(context, value, freshness);
    }
  }

  /// The line that says how old the data is and whether it is a saved copy.
  Widget? _freshness(BuildContext context, PulseTokens t) {
    final label = data.lastUpdatedLabel;
    if (label == null) return null;

    final text = data.isStale
        ? 'Saved copy, updated $label'
        : 'Updated $label';

    return Padding(
      padding: const EdgeInsets.only(top: PulseSpacing.xs),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            data.isStale ? Icons.cloud_off_outlined : Icons.schedule_outlined,
            size: 14,
            color: t.textSecondary,
          ),
          const SizedBox(width: PulseSpacing.xs),
          Flexible(
            child: Text(
              text,
              style: PulseType.caption.copyWith(color: t.textSecondary),
            ),
          ),
        ],
      ),
    );
  }
}
