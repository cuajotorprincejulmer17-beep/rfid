import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/session.dart';
import '../../core/auth/auth_controller.dart';
import '../../core/theme/pulse_theme.dart';
import '../../core/theme/pulse_tokens.dart';
import '../../shared/widgets/pulse_button.dart';
import '../../shared/widgets/pulse_card.dart';
import '../../shared/widgets/pulse_page.dart';
import '../../shared/widgets/pulse_text_field.dart';
import 'server_address_card.dart';

/// Turns a failed sign-in into a sentence the student can act on.
///
/// Branches on the backend error code, never on its message text.
String authErrorText(AuthController auth, String serverUrl) {
  return switch (auth.lastErrorCode) {
    'network' || 'timeout' =>
      "Couldn't reach the school server at $serverUrl. Check that you are "
          'on the school WiFi and that the server address below is right.',
    'invalid_credentials' => 'Incorrect student number or password.',
    'invalid_claim' =>
      'The student number or activation code is not valid. Ask the school '
          'office for a new code.',
    _ => auth.lastErrorMessage ?? 'Something went wrong. Please try again.',
  };
}

/// Sign in with a student number and password.
class SignInPage extends ConsumerStatefulWidget {
  const SignInPage({super.key});

  @override
  ConsumerState<SignInPage> createState() => _SignInPageState();
}

class _SignInPageState extends ConsumerState<SignInPage> {
  final TextEditingController _studentNumber = TextEditingController();
  final TextEditingController _password = TextEditingController();
  bool _busy = false;
  bool _showPassword = false;
  String? _error;

  @override
  void dispose() {
    _studentNumber.dispose();
    _password.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.pulse;

    return Scaffold(
      backgroundColor: t.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(PulseSpacing.lg),
          child: AutofillGroup(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: PulseSpacing.xl),
                Text(
                  'Pulse',
                  style: PulseType.title.copyWith(color: t.textPrimary),
                ),
                const SizedBox(height: PulseSpacing.xs),
                Text(
                  'Sign in with your student number.',
                  style: PulseType.body.copyWith(color: t.textSecondary),
                ),
                const SizedBox(height: PulseSpacing.xl),
                PulseTextField(
                  controller: _studentNumber,
                  label: 'Student number',
                  hint: 'For example: 2024-00123',
                  textInputAction: TextInputAction.next,
                  autofillHints: const [AutofillHints.username],
                  enabled: !_busy,
                ),
                const SizedBox(height: PulseSpacing.lg),
                PulseTextField(
                  controller: _password,
                  label: 'Password',
                  obscureText: !_showPassword,
                  textInputAction: TextInputAction.done,
                  autofillHints: const [AutofillHints.password],
                  enabled: !_busy,
                  onSubmitted: (_) => _submit(),
                  suffix: IconButton(
                    icon: Icon(
                      _showPassword
                          ? Icons.visibility_off_outlined
                          : Icons.visibility_outlined,
                    ),
                    tooltip: _showPassword ? 'Hide password' : 'Show password',
                    onPressed: () =>
                        setState(() => _showPassword = !_showPassword),
                  ),
                ),
                if (_error != null) ...[
                  const SizedBox(height: PulseSpacing.md),
                  _ErrorText(_error!),
                ],
                const SizedBox(height: PulseSpacing.xl),
                ListenableBuilder(
                  listenable: Listenable.merge([_studentNumber, _password]),
                  builder: (context, _) => PulseButton(
                    label: 'Sign in',
                    busy: _busy,
                    onPressed:
                        (_studentNumber.text.trim().length >= 2 &&
                            _password.text.isNotEmpty)
                        ? _submit
                        : null,
                  ),
                ),
                const SizedBox(height: PulseSpacing.md),
                PulseButton(
                  label: 'First time? Activate your account',
                  variant: PulseButtonVariant.secondary,
                  onPressed: _busy ? null : () => context.push('/claim'),
                ),
                const SizedBox(height: PulseSpacing.xl),
                const ServerAddressCard(),
                const SizedBox(height: PulseSpacing.md),
                Text(
                  'Forgot your password? The school office can reset your '
                  'account and give you a new activation code.',
                  style: PulseType.caption.copyWith(color: t.textSecondary),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _submit() async {
    final auth = ref.read(authControllerProvider);
    if (auth == null || _busy) return;
    if (_studentNumber.text.trim().length < 2 || _password.text.isEmpty) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    final ok = await auth.signIn(
      studentNumber: _studentNumber.text,
      password: _password.text,
    );
    if (!mounted) return;
    setState(() {
      _busy = false;
      if (!ok) {
        _error = authErrorText(auth, ref.read(serverUrlProvider));
        _password.clear();
      }
    });
    if (ok) TextInput.finishAutofillContext();
  }
}

/// First-time activation with the one-time code from the school office.
class ClaimAccountPage extends ConsumerStatefulWidget {
  const ClaimAccountPage({super.key});

  @override
  ConsumerState<ClaimAccountPage> createState() => _ClaimAccountPageState();
}

class _ClaimAccountPageState extends ConsumerState<ClaimAccountPage> {
  final TextEditingController _studentNumber = TextEditingController();
  final TextEditingController _code = TextEditingController();
  final TextEditingController _password = TextEditingController();
  final TextEditingController _confirm = TextEditingController();
  bool _busy = false;
  String? _error;
  String? _passwordError;
  String? _confirmError;

  @override
  void dispose() {
    _studentNumber.dispose();
    _code.dispose();
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.pulse;

    return PulsePage(
      title: 'Activate your account',
      subtitle: 'One time only',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          PulseCard(
            child: Text(
              'The school office gives you an activation code after your RFID '
              'card is registered. Enter it here with your student number and '
              'choose a password.',
              style: PulseType.caption.copyWith(color: t.textSecondary),
            ),
          ),
          const SizedBox(height: PulseSpacing.lg),
          PulseTextField(
            controller: _studentNumber,
            label: 'Student number',
            textInputAction: TextInputAction.next,
            enabled: !_busy,
          ),
          const SizedBox(height: PulseSpacing.lg),
          PulseTextField(
            controller: _code,
            label: 'Activation code',
            hint: 'ABCD-2345',
            textCapitalization: TextCapitalization.characters,
            textInputAction: TextInputAction.next,
            enabled: !_busy,
          ),
          const SizedBox(height: PulseSpacing.lg),
          PulseTextField(
            controller: _password,
            label: 'New password',
            hint: 'At least 8 characters',
            obscureText: true,
            autofillHints: const [AutofillHints.newPassword],
            textInputAction: TextInputAction.next,
            errorText: _passwordError,
            enabled: !_busy,
          ),
          const SizedBox(height: PulseSpacing.lg),
          PulseTextField(
            controller: _confirm,
            label: 'Confirm password',
            obscureText: true,
            textInputAction: TextInputAction.done,
            errorText: _confirmError,
            enabled: !_busy,
            onSubmitted: (_) => _submit(),
          ),
          if (_error != null) ...[
            const SizedBox(height: PulseSpacing.md),
            _ErrorText(_error!),
          ],
          const SizedBox(height: PulseSpacing.xl),
          ListenableBuilder(
            listenable: Listenable.merge([
              _studentNumber,
              _code,
              _password,
              _confirm,
            ]),
            builder: (context, _) => PulseButton(
              label: 'Activate and sign in',
              busy: _busy,
              onPressed: _filled ? _submit : null,
            ),
          ),
          const SizedBox(height: PulseSpacing.xl),
          const ServerAddressCard(),
        ],
      ),
    );
  }

  bool get _filled =>
      _studentNumber.text.trim().length >= 2 &&
      _code.text.trim().length >= 8 &&
      _password.text.isNotEmpty &&
      _confirm.text.isNotEmpty;

  Future<void> _submit() async {
    final auth = ref.read(authControllerProvider);
    if (auth == null || _busy || !_filled) return;
    final tooShort = _password.text.length < 8;
    final mismatch = _password.text != _confirm.text;
    setState(() {
      _passwordError = tooShort ? 'Use at least 8 characters.' : null;
      _confirmError = mismatch ? 'The passwords do not match.' : null;
      _error = null;
    });
    if (tooShort || mismatch) return;

    setState(() => _busy = true);
    final ok = await auth.claimAccount(
      studentNumber: _studentNumber.text,
      claimCode: _code.text,
      password: _password.text,
    );
    if (!mounted) return;
    setState(() {
      _busy = false;
      if (!ok) _error = authErrorText(auth, ref.read(serverUrlProvider));
    });
  }
}

/// An inline error under a form.
class _ErrorText extends StatelessWidget {
  const _ErrorText(this.message);

  final String message;

  @override
  Widget build(BuildContext context) {
    final t = context.pulse;
    return Semantics(
      liveRegion: true,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.error_outline, size: 18, color: t.error),
          const SizedBox(width: PulseSpacing.sm),
          Expanded(
            child: Text(
              message,
              style: PulseType.caption.copyWith(color: t.error),
            ),
          ),
        ],
      ),
    );
  }
}
