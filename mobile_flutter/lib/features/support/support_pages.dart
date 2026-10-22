import 'package:flutter/material.dart';

import '../../core/theme/pulse_theme.dart';
import '../../core/theme/pulse_tokens.dart';
import '../../shared/models/demo_models.dart';
import '../../shared/widgets/pulse_button.dart';
import '../../shared/widgets/pulse_card.dart';
import '../../shared/widgets/pulse_page.dart';
import '../../shared/widgets/pulse_sheet.dart';
import '../../shared/widgets/pulse_text_field.dart';

/// The Assistance page.
///
/// The emergency tile shows static contact information and says clearly
/// that it is demo content. It does not place calls.
class AssistancePage extends StatelessWidget {
  const AssistancePage({super.key, required this.paths});

  final List<AssistancePath> paths;

  @override
  Widget build(BuildContext context) {
    final t = context.pulse;

    return PulsePage(
      title: 'Assistance',
      subtitle: 'Where to go for help',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final path in paths)
            Padding(
              padding: const EdgeInsets.only(bottom: PulseSpacing.md),
              child: PulseCard(
                onTap: path.id == 'as-4' ? () => _showEmergency(context) : null,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(_icon(path.iconName), size: 22, color: t.navSelected),
                    const SizedBox(width: PulseSpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            path.title,
                            style: PulseType.body.copyWith(color: t.textPrimary),
                          ),
                          const SizedBox(height: PulseSpacing.xs),
                          Text(
                            path.description,
                            style: PulseType.caption
                                .copyWith(color: t.textSecondary),
                          ),
                          if (path.id == 'as-4') ...[
                            const SizedBox(height: PulseSpacing.sm),
                            Text(
                              'Demo content. It does not place calls.',
                              style: PulseType.caption.copyWith(color: t.warning),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  static IconData _icon(String name) => switch (name) {
        'credit_card' => Icons.credit_card_outlined,
        'badge' => Icons.badge_outlined,
        'school' => Icons.school_outlined,
        _ => Icons.emergency_outlined,
      };

  Future<void> _showEmergency(BuildContext context) async {
    final t = context.pulse;
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: t.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(PulseRadius.sheet),
        ),
      ),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(PulseSpacing.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Emergency contacts',
                style: PulseType.heading.copyWith(color: t.textPrimary),
              ),
              const SizedBox(height: PulseSpacing.md),
              _Contact(label: 'Campus security desk', value: '+63 900 000 0004'),
              _Contact(label: 'Registrar office', value: '+63 900 000 0003'),
              const SizedBox(height: PulseSpacing.md),
              Text(
                'Demo content. These numbers are placeholders and the app '
                'does not place calls.',
                style: PulseType.caption.copyWith(color: t.warning),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// One contact line in the emergency sheet.
class _Contact extends StatelessWidget {
  const _Contact({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final t = context.pulse;
    return Padding(
      padding: const EdgeInsets.only(bottom: PulseSpacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: PulseType.caption.copyWith(color: t.textSecondary)),
          Text(value, style: PulseType.body.copyWith(color: t.textPrimary)),
        ],
      ),
    );
  }
}

/// The FAQ page.
class FaqPage extends StatefulWidget {
  const FaqPage({super.key, required this.items});

  final List<FaqItem> items;

  @override
  State<FaqPage> createState() => _FaqPageState();
}

class _FaqPageState extends State<FaqPage> {
  final Set<String> _expanded = <String>{};

  @override
  Widget build(BuildContext context) {
    final t = context.pulse;

    return PulsePage(
      title: 'FAQ',
      subtitle: 'Common questions',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (widget.items.isEmpty)
            Text(
              'No questions match that search.',
              style: PulseType.body.copyWith(color: t.textSecondary),
            ),
          for (final item in widget.items)
            Padding(
              padding: const EdgeInsets.only(bottom: PulseSpacing.md),
              child: PulseCard(
                onTap: () => setState(() {
                  if (!_expanded.add(item.id)) _expanded.remove(item.id);
                }),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            item.question,
                            style: PulseType.body.copyWith(color: t.textPrimary),
                          ),
                        ),
                        Icon(
                          _expanded.contains(item.id)
                              ? Icons.expand_less_rounded
                              : Icons.expand_more_rounded,
                          size: 20,
                          color: t.textSecondary,
                        ),
                      ],
                    ),
                    if (_expanded.contains(item.id)) ...[
                      const SizedBox(height: PulseSpacing.sm),
                      Text(
                        item.answer,
                        style: PulseType.caption.copyWith(color: t.textSecondary),
                      ),
                    ],
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// The Contact Support page.
class ContactSupportPage extends StatelessWidget {
  const ContactSupportPage({super.key});

  @override
  Widget build(BuildContext context) {
    final t = context.pulse;

    return PulsePage(
      title: 'Contact Support',
      subtitle: 'Tell us what happened',
      child: Builder(
        builder: (context) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            PulseCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Before you write',
                    style: PulseType.heading.copyWith(color: t.textPrimary),
                  ),
                  const SizedBox(height: PulseSpacing.sm),
                  Text(
                    'Attendance problems are usually fixed fastest at the '
                    'registrar, because they can check the reader log for the '
                    'time you tapped.',
                    style: PulseType.caption.copyWith(color: t.textSecondary),
                  ),
                ],
              ),
            ),
            const SizedBox(height: PulseSpacing.lg),
            PulseButton(
              label: 'Open the contact form',
              icon: Icons.chat_bubble_outline,
              onPressed: () => showPulseSheet<void>(
                context: context,
                builder: (context) => const ContactSupportSheet(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The contact form sheet.
class ContactSupportSheet extends StatefulWidget {
  const ContactSupportSheet({super.key});

  @override
  State<ContactSupportSheet> createState() => _ContactSupportSheetState();
}

class _ContactSupportSheetState extends State<ContactSupportSheet> {
  final TextEditingController _topic = TextEditingController();
  final TextEditingController _message = TextEditingController();
  String? _topicError;
  bool _busy = false;
  bool _sent = false;

  @override
  void dispose() {
    _topic.dispose();
    _message.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.pulse;

    if (_sent) {
      return PulseSheet(
        title: 'Message sent',
        subtitle: 'The registrar will get back to you.',
        primaryLabel: 'Done',
        onPrimary: () => Navigator.of(context).pop(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.check_circle_outline, size: 20, color: t.success),
                const SizedBox(width: PulseSpacing.sm),
                Expanded(
                  child: Text(
                    'Your message was recorded.',
                    style: PulseType.body.copyWith(color: t.textPrimary),
                  ),
                ),
              ],
            ),
          ],
        ),
      );
    }

    final valid = _topic.text.trim().isNotEmpty;

    return PulseSheet(
      title: 'Contact Support',
      subtitle: 'Tell us what you need help with.',
      primaryLabel: 'Send message',
      primaryEnabled: valid,
      busy: _busy,
      onPrimary: _submit,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          PulseTextField(
            controller: _topic,
            label: 'Topic',
            hint: 'For example: attendance problem',
            errorText: _topicError,
          ),
          const SizedBox(height: PulseSpacing.lg),
          PulseTextField(
            controller: _message,
            label: 'Message',
            hint: 'What happened?',
            maxLines: 4,
          ),
        ],
      ),
    );
  }

  Future<void> _submit() async {
    if (_topic.text.trim().isEmpty) {
      setState(() => _topicError = 'Say what it is about.');
      return;
    }
    setState(() {
      _topicError = null;
      _busy = true;
    });

    await Future<void>.delayed(const Duration(milliseconds: 400));
    if (!mounted) return;
    setState(() {
      _busy = false;
      _sent = true;
    });
  }
}
