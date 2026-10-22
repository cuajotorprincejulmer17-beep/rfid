import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/theme/pulse_theme.dart';
import '../../core/theme/pulse_tokens.dart';
import '../../shared/models/demo_models.dart';
import '../../shared/widgets/pulse_card.dart';
import '../../shared/widgets/pulse_page.dart';
import '../../shared/widgets/pulse_text_field.dart';

/// The Directory page.
///
/// Tapping an entry opens a sheet with its details and the actions to copy
/// its email or its phone number.
class DirectoryPage extends StatefulWidget {
  const DirectoryPage({
    super.key,
    required this.entries,
    this.query = '',
    this.onQueryChanged,
  });

  final List<DirectoryEntry> entries;
  final String query;
  final ValueChanged<String>? onQueryChanged;

  @override
  State<DirectoryPage> createState() => _DirectoryPageState();
}

class _DirectoryPageState extends State<DirectoryPage> {
  late final TextEditingController _controller =
      TextEditingController(text: widget.query);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.pulse;

    return PulsePage(
      title: 'Directory',
      subtitle: 'People and services',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PulseTextField(
            controller: _controller,
            hint: 'Search people and services',
            onSubmitted: widget.onQueryChanged,
          ),
          const SizedBox(height: PulseSpacing.lg),
          if (widget.entries.isEmpty)
            Text(
              'Nothing matches that search.',
              style: PulseType.body.copyWith(color: t.textSecondary),
            )
          else
            for (final entry in widget.entries)
              Padding(
                padding: const EdgeInsets.only(bottom: PulseSpacing.md),
                child: PulseCard(
                  onTap: () => _openSheet(context, entry),
                  child: Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: t.softFill,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          entry.email == null && entry.phone == null
                              ? Icons.groups_outlined
                              : Icons.person_outline,
                          size: 20,
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
                              entry.name,
                              style: PulseType.body
                                  .copyWith(color: t.textPrimary),
                            ),
                            const SizedBox(height: PulseSpacing.xs),
                            Text(
                              '${entry.role} - ${entry.department}',
                              style: PulseType.caption
                                  .copyWith(color: t.textSecondary),
                            ),
                          ],
                        ),
                      ),
                      Icon(
                        Icons.chevron_right_rounded,
                        size: 20,
                        color: t.textSecondary,
                      ),
                    ],
                  ),
                ),
              ),
        ],
      ),
    );
  }

  Future<void> _openSheet(BuildContext context, DirectoryEntry entry) async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: context.pulse.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(PulseRadius.sheet),
        ),
      ),
      builder: (context) {
        final t = context.pulse;
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(PulseSpacing.lg),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entry.name,
                  style: PulseType.heading.copyWith(color: t.textPrimary),
                ),
                const SizedBox(height: PulseSpacing.xs),
                Text(
                  '${entry.role} - ${entry.department}',
                  style: PulseType.body.copyWith(color: t.textSecondary),
                ),
                const SizedBox(height: PulseSpacing.lg),
                if (entry.email != null)
                  _ContactAction(
                    icon: Icons.mail_outline,
                    label: entry.email!,
                    onTap: () => _copy(context, entry.email!, 'Email'),
                  ),
                if (entry.phone != null)
                  _ContactAction(
                    icon: Icons.phone_outlined,
                    label: entry.phone!,
                    onTap: () => _copy(context, entry.phone!, 'Phone'),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _copy(BuildContext context, String value, String what) async {
    await Clipboard.setData(ClipboardData(text: value));
    if (!context.mounted) return;
    Navigator.of(context).pop();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$what copied to the clipboard.')),
    );
  }
}

/// A row that copies a contact detail.
class _ContactAction extends StatelessWidget {
  const _ContactAction({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.pulse;
    return Semantics(
      button: true,
      label: 'Copy $label',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: PulseSpacing.sm),
          child: Row(
            children: [
              Icon(icon, size: 20, color: t.navSelected),
              const SizedBox(width: PulseSpacing.md),
              Expanded(
                child: Text(
                  label,
                  style: PulseType.body.copyWith(color: t.textPrimary),
                ),
              ),
              Icon(Icons.copy_outlined, size: 18, color: t.textSecondary),
            ],
          ),
        ),
      ),
    );
  }
}
