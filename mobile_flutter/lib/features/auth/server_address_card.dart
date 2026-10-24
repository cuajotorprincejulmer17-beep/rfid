import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/session.dart';
import '../../core/api/api_client.dart';
import '../../core/api/api_exception.dart';
import '../../core/theme/pulse_theme.dart';
import '../../core/theme/pulse_tokens.dart';
import '../../shared/widgets/pulse_card.dart';
import '../../shared/widgets/pulse_sheet.dart';
import '../../shared/widgets/pulse_text_field.dart';

/// Shows the school server address and lets the student change it.
///
/// A phone reaches the server over the school WiFi at the PC's LAN address,
/// which changes between networks, so it cannot be fixed at build time.
class ServerAddressCard extends ConsumerWidget {
  const ServerAddressCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.pulse;
    final url = ref.watch(serverUrlProvider);

    return PulseCard(
      onTap: () => showPulseSheet<void>(
        context: context,
        builder: (context) => const ServerAddressSheet(),
      ),
      child: Row(
        children: [
          Icon(Icons.dns_outlined, size: 22, color: t.textSecondary),
          const SizedBox(width: PulseSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'School server',
                  style: PulseType.label.copyWith(color: t.textSecondary),
                ),
                const SizedBox(height: PulseSpacing.xs),
                Text(url, style: PulseType.body.copyWith(color: t.textPrimary)),
              ],
            ),
          ),
          Text('Change', style: PulseType.label.copyWith(color: t.accentCyan)),
        ],
      ),
    );
  }
}

/// The sheet that edits and tests the server address.
class ServerAddressSheet extends ConsumerStatefulWidget {
  const ServerAddressSheet({super.key});

  @override
  ConsumerState<ServerAddressSheet> createState() => _ServerAddressSheetState();
}

class _ServerAddressSheetState extends ConsumerState<ServerAddressSheet> {
  late final TextEditingController _url = TextEditingController(
    text: ref.read(serverUrlProvider),
  );
  String? _error;
  String? _result;
  bool _resultOk = false;
  bool _testing = false;

  @override
  void dispose() {
    _url.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.pulse;
    final signedIn = ref.watch(authControllerProvider)?.isSignedIn ?? false;

    return PulseSheet(
      title: 'School server',
      subtitle: 'The address of the PC running the attendance server.',
      primaryLabel: 'Save',
      onPrimary: _save,
      secondaryLabel: 'Test connection',
      onSecondary: _testing ? null : _test,
      busy: _testing,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          PulseTextField(
            controller: _url,
            label: 'Server address',
            hint: 'http://192.168.1.20:5001',
            keyboardType: TextInputType.url,
            errorText: _error,
            onSubmitted: (_) => _test(),
          ),
          const SizedBox(height: PulseSpacing.sm),
          Text(
            'Use the PC\'s WiFi (IPv4) address and port 5001. The phone and '
            'the PC must be on the same network.',
            style: PulseType.caption.copyWith(color: t.textSecondary),
          ),
          if (signedIn) ...[
            const SizedBox(height: PulseSpacing.sm),
            Text(
              'Saving a different address signs you out.',
              style: PulseType.caption.copyWith(color: t.warning),
            ),
          ],
          if (_result != null) ...[
            const SizedBox(height: PulseSpacing.md),
            Row(
              children: [
                Icon(
                  _resultOk ? Icons.check_circle_outline : Icons.error_outline,
                  size: 18,
                  color: _resultOk ? t.success : t.error,
                ),
                const SizedBox(width: PulseSpacing.sm),
                Expanded(
                  child: Text(
                    _result!,
                    style: PulseType.caption.copyWith(color: t.textPrimary),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  bool _validate() {
    final ok = isValidServerUrl(_url.text);
    setState(
      () => _error = ok ? null : 'Enter an address like 192.168.1.20:5001',
    );
    return ok;
  }

  Future<void> _test() async {
    if (!_validate()) return;
    final current = ref.read(apiClientProvider);
    if (current == null) return;
    setState(() {
      _testing = true;
      _result = null;
    });
    final probe = ApiClient(
      baseUrl: normaliseServerUrl(_url.text),
      tokenStore: current.tokenStore,
      timeout: const Duration(seconds: 5),
    );
    String result;
    var ok = false;
    try {
      await probe.health();
      ok = true;
      result = 'Connected. The school server answered.';
    } on ApiException catch (e) {
      result = e.message;
    } finally {
      probe.dispose();
    }
    if (!mounted) return;
    setState(() {
      _testing = false;
      _resultOk = ok;
      _result = result;
    });
  }

  Future<void> _save() async {
    if (!_validate()) return;
    await ref.read(serverUrlProvider.notifier).setUrl(_url.text);
    if (mounted) Navigator.of(context).pop();
  }
}
