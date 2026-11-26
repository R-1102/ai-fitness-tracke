import 'package:flutter/material.dart';

import '../../core/motion.dart';
import '../../core/theme.dart';
import '../../core/validators.dart';
import '../../models/user_profile.dart';
import '../../services/auth_service.dart';
import '../../services/services.dart';
import '../../widgets/ui.dart';
import 'login_screen.dart';

/// Sign-up step 1. Step 2 (gender + level) is [ProfileSetupScreen], shown
/// automatically by the AuthGate while the profile is incomplete.
class SignUpScreen extends StatefulWidget {
  const SignUpScreen({super.key});

  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _age = TextEditingController();
  final _weight = TextEditingController();
  final _height = TextEditingController();
  bool _obscure = true;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _password.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    for (final c in [_name, _email, _password, _age, _weight, _height]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final user = await authService.signUp(email: _email.text, password: _password.text);
      await userRepository.saveProfile(UserProfile(
        uid: user.uid,
        name: _name.text.trim(),
        email: _email.text.trim(),
        age: int.parse(_age.text.trim()),
        weightKg: double.parse(_weight.text.trim()),
        heightCm: double.parse(_height.text.trim()),
      ));
      if (mounted) Navigator.of(context).popUntil((r) => r.isFirst);
    } on AuthFailure catch (e) {
      setState(() => _error = e.message);
    } catch (e) {
      setState(() => _error = 'Could not create account: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = _password.text;
    Widget stagger(int i, Widget child) => Entrance(delay: Motion.stagger(i, stepMs: 40), child: child);

    return Scaffold(
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
            children: [
              stagger(0, const Row(children: [
                AppBackButton(),
                SizedBox(width: 14),
                Expanded(child: StepProgress(step: 1, total: 2)),
              ])),
              const SizedBox(height: 20),
              stagger(1, Text('Create your account', style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontSize: 28))),
              const SizedBox(height: 6),
              stagger(1, const Text('Your body stats help us estimate calories.', style: TextStyle(fontSize: 14, color: AppColors.muted))),
              const SizedBox(height: 20),
              stagger(2, LabeledField(
                label: 'Name',
                child: TextFormField(
                  controller: _name,
                  textCapitalization: TextCapitalization.words,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(hintText: 'Your name'),
                  validator: Validators.name,
                ),
              )),
              const SizedBox(height: 14),
              stagger(3, LabeledField(
                label: 'Email',
                child: TextFormField(
                  controller: _email,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(hintText: 'you@example.com'),
                  validator: Validators.email,
                ),
              )),
              const SizedBox(height: 14),
              stagger(4, LabeledField(
                label: 'Password',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextFormField(
                      controller: _password,
                      obscureText: _obscure,
                      decoration: InputDecoration(
                        suffixIcon: IconButton(
                          tooltip: _obscure ? 'Show password' : 'Hide password',
                          icon: Icon(_obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined, color: AppColors.muted),
                          onPressed: () => setState(() => _obscure = !_obscure),
                        ),
                      ),
                      validator: Validators.password,
                    ),
                    const SizedBox(height: 10),
                    GridView.count(
                      crossAxisCount: 2,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      childAspectRatio: 7,
                      mainAxisSpacing: 4,
                      children: [
                        _Rule('8+ characters', Validators.hasMinLength(p)),
                        _Rule('Uppercase letter', Validators.hasUpper(p)),
                        _Rule('Lowercase letter', Validators.hasLower(p)),
                        _Rule('A number', Validators.hasDigit(p)),
                      ],
                    ),
                  ],
                ),
              )),
              const SizedBox(height: 14),
              stagger(5, Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: _numberField(_age, 'Age', '23', Validators.number(label: 'Age', min: 10, max: 100))),
                  const SizedBox(width: 10),
                  Expanded(child: _numberField(_weight, 'Weight · kg', '60', Validators.number(label: 'Weight', min: 25, max: 300))),
                  const SizedBox(width: 10),
                  Expanded(child: _numberField(_height, 'Height · cm', '165', Validators.number(label: 'Height', min: 100, max: 250))),
                ],
              )),
              AnimatedSize(
                duration: Motion.fast,
                child: _error == null
                    ? const SizedBox(width: double.infinity, height: 0)
                    : Padding(
                        padding: const EdgeInsets.only(top: 16),
                        child: Text(_error!, style: const TextStyle(color: AppColors.warn, fontWeight: FontWeight.w600)),
                      ),
              ),
              const SizedBox(height: 28),
              stagger(6, PrimaryButton(label: 'Continue', icon: Icons.arrow_forward_rounded, busy: _busy, onPressed: _submit)),
              const SizedBox(height: 12),
              stagger(7, Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('Already have an account?', style: TextStyle(color: AppColors.muted)),
                  TextButton(
                    onPressed: () => Navigator.of(context)
                        .pushReplacement(MaterialPageRoute(builder: (_) => const LoginScreen())),
                    child: const Text('Log in'),
                  ),
                ],
              )),
            ],
          ),
        ),
      ),
    );
  }

  Widget _numberField(TextEditingController c, String label, String hint, String? Function(String?) validator) =>
      LabeledField(
        label: label,
        child: TextFormField(
          controller: c,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(hintText: hint, errorMaxLines: 3),
          validator: validator,
        ),
      );
}

/// Password rule that animates to a green check once satisfied.
class _Rule extends StatelessWidget {
  const _Rule(this.label, this.ok);
  final String label;
  final bool ok;

  @override
  Widget build(BuildContext context) {
    final color = ok ? AppColors.success : AppColors.muted;
    return Row(
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          width: 16,
          height: 16,
          decoration: BoxDecoration(color: ok ? AppColors.success : const Color(0xFFC9D1DD), shape: BoxShape.circle),
          child: AnimatedScale(
            scale: ok ? 1 : 0.4,
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeOutBack,
            child: const Icon(Icons.check_rounded, size: 11, color: Colors.white),
          ),
        ),
        const SizedBox(width: 8),
        Flexible(
          child: AnimatedDefaultTextStyle(
            duration: const Duration(milliseconds: 250),
            style: TextStyle(fontFamily: kFont, fontSize: 12, color: color, fontWeight: ok ? FontWeight.w600 : FontWeight.w400),
            child: Text(label, overflow: TextOverflow.ellipsis),
          ),
        ),
      ],
    );
  }
}
