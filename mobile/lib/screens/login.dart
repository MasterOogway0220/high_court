import 'package:flutter/material.dart';

import '../data.dart';
import '../theme.dart';
import '../ui.dart';

/// Mirrors src/app/(auth)/login — enrolment number or registered mobile, plus a
/// password. There is no self-service reset: the office issues credentials.
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key, this.notice});

  /// Set when the gate is being shown because something upstream failed —
  /// a demo auto-login that did not take, for instance.
  final String? notice;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _identifier = TextEditingController();
  final _password = TextEditingController();
  late String? _error = widget.notice;
  bool _busy = false;

  @override
  void dispose() {
    _identifier.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });

    final error = await Data.signIn(_identifier.text, _password.text);

    // On success the auth listener in AuthGate swaps the screen out from under
    // us, so only the failure path has anything left to say.
    if (!mounted) return;
    setState(() {
      _busy = false;
      _error = error;
    });
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: C.canvas,
    body: SafeArea(
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // The mark: a dot field behind the monogram, as the app draws
                // any surface that is pattern rather than content.
                Align(
                  alignment: Alignment.centerLeft,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: SizedBox(
                      height: 64,
                      width: 64,
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          Container(color: C.ink),
                          const DotField(
                            gap: 7,
                            radius: 1.1,
                            color: Color(0x26FFFFFF),
                          ),
                          const Center(
                            child: Text(
                              'GH',
                              style: TextStyle(
                                fontFamily: 'Doto',
                                fontSize: 26,
                                fontWeight: FontWeight.w700,
                                color: C.onDark,
                                height: 1,
                                letterSpacing: 1,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 28),

                const Text('GUWAHATI HIGH COURT', style: T.eyebrow),
                const SizedBox(height: 10),
                const Text('Bar Association', style: T.largeTitle),
                const SizedBox(height: 8),
                Text(
                  'Sign in with the enrolment number or mobile number on the '
                  'Association roll.',
                  style: T.subhead,
                ),
                const SizedBox(height: 32),

                AppField(
                  label: 'Enrolment number or mobile',
                  child: AppInput(
                    controller: _identifier,
                    placeholder: 'GHC/1995/108',
                    autofocus: true,
                    invalid: _error != null,
                  ),
                ),
                const SizedBox(height: 16),
                AppField(
                  label: 'Password',
                  child: AppInput(
                    controller: _password,
                    obscure: true,
                    invalid: _error != null,
                    onSubmitted: (_) => _submit(),
                  ),
                ),

                if (_error != null) ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: C.accentWash,
                      borderRadius: BorderRadius.circular(kRControl),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(
                          Icons.error_outline_rounded,
                          size: 17,
                          color: C.accent,
                        ),
                        const SizedBox(width: 9),
                        Expanded(
                          child: Text(
                            _error!,
                            style: T.footnote.copyWith(
                              color: C.accent,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                const SizedBox(height: 24),
                AppButton(
                  'Sign in',
                  expand: true,
                  busy: _busy,
                  onPressed: _submit,
                ),
                const SizedBox(height: 18),
                Text(
                  'First time signing in, or forgotten your password? '
                  'Contact the Association office.',
                  textAlign: TextAlign.center,
                  style: T.caption,
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
