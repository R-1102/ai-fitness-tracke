import 'package:flutter/material.dart';

import '../../core/motion.dart';
import '../../core/theme.dart';
import '../../core/validators.dart';
import '../../services/auth_service.dart';
import '../../services/services.dart';
import '../../widgets/ui.dart';
import 'signup_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _obscure = true;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await authService.signIn(email: _email.text, password: _password.text);
      if (mounted) Navigator.of(context).popUntil((r) => r.isFirst);
    } on AuthFailure catch (e) {
      setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _resetPassword() async {
    final messenger = ScaffoldMessenger.of(context);
    if (Validators.email(_email.text) != null) {
      setState(() => _error = 'Enter your email above first.');
      return;
    }
    try {
      await authService.sendPasswordReset(_email.text);
      messenger.showSnackBar(const SnackBar(content: Text('Password reset email sent.')));
    } on AuthFailure catch (e) {
      setState(() => _error = e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    Widget stagger(int i, Widget child) => Entrance(delay: Motion.stagger(i), child: child);

    return Scaffold(
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: CustomScrollView(
            slivers: [
              SliverFillRemaining(
                hasScrollBody: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      stagger(0, const Align(alignment: Alignment.centerLeft, child: AppBackButton())),
                      const SizedBox(height: 24),
                      stagger(1, Text('Welcome back', style: Theme.of(context).textTheme.headlineMedium)),
                      const SizedBox(height: 8),
                      stagger(1, const Text('Log in to continue your training.', style: TextStyle(fontSize: 15, color: AppColors.muted))),
                      const SizedBox(height: 24),
                      stagger(
                        2,
                        LabeledField(
                          label: 'Email',
                          child: TextFormField(
                            controller: _email,
                            keyboardType: TextInputType.emailAddress,
                            autofillHints: const [AutofillHints.email],
                            textInputAction: TextInputAction.next,
                            decoration: const InputDecoration(hintText: 'you@example.com'),
                            validator: Validators.email,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      stagger(
                        3,
                        LabeledField(
                          label: 'Password',
                          child: TextFormField(
                            controller: _password,
                            obscureText: _obscure,
                            autofillHints: const [AutofillHints.password],
                            decoration: InputDecoration(
                              suffixIcon: IconButton(
                                tooltip: _obscure ? 'Show password' : 'Hide password',
                                icon: AnimatedSwitcher(
                                  duration: Motion.fast,
                                  child: Icon(
                                    _obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                                    key: ValueKey(_obscure),
                                    color: AppColors.muted,
                                  ),
                                ),
                                onPressed: () => setState(() => _obscure = !_obscure),
                              ),
                            ),
                            validator: (v) => (v ?? '').isEmpty ? 'Enter your password' : null,
                            onFieldSubmitted: (_) => _login(),
                          ),
                        ),
                      ),
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(onPressed: _resetPassword, child: const Text('Forgot password?')),
                      ),
                      AnimatedSize(
                        duration: Motion.fast,
                        child: _error == null
                            ? const SizedBox(width: double.infinity)
                            : Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: Text(_error!, style: const TextStyle(color: AppColors.warn, fontWeight: FontWeight.w600)),
                              ),
                      ),
                      const Spacer(),
                      const SizedBox(height: 24),
                      stagger(4, PrimaryButton(label: 'Log in', busy: _busy, onPressed: _login)),
                      const SizedBox(height: 16),
                      stagger(
                        5,
                        const Row(children: [
                          Expanded(child: Divider(color: AppColors.border)),
                          Padding(padding: EdgeInsets.symmetric(horizontal: 12), child: Text('or', style: TextStyle(color: AppColors.muted, fontSize: 13))),
                          Expanded(child: Divider(color: AppColors.border)),
                        ]),
                      ),
                      const SizedBox(height: 16),
                      stagger(
                        6,
                        SecondaryButton(
                          label: 'Create a new account',
                          onPressed: () => Navigator.of(context)
                              .pushReplacement(MaterialPageRoute(builder: (_) => const SignUpScreen())),
                        ),
                      ),
                      const SizedBox(height: 16),
                      stagger(
                        7,
                        const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.lock_outline_rounded, size: 14, color: AppColors.muted),
                            SizedBox(width: 6),
                            Text('Secured by Firebase Authentication', style: TextStyle(fontSize: 12, color: AppColors.muted)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
