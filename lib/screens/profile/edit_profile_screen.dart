import 'package:flutter/material.dart';

import '../../core/motion.dart';
import '../../core/theme.dart';
import '../../core/validators.dart';
import '../../models/exercise.dart';
import '../../models/user_profile.dart';
import '../../services/services.dart';
import '../../widgets/ui.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key, required this.profile});

  final UserProfile profile;

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.profile.name);
  late final _age = TextEditingController(text: widget.profile.age?.toString() ?? '');
  late final _weight = TextEditingController(text: widget.profile.weightKg?.toStringAsFixed(0) ?? '');
  late final _height = TextEditingController(text: widget.profile.heightCm?.toStringAsFixed(0) ?? '');
  late Gender _gender = widget.profile.gender ?? Gender.female;
  late Level _level = widget.profile.levelOrDefault;
  bool _busy = false;
  bool _saved = false;

  @override
  void dispose() {
    for (final c in [_name, _age, _weight, _height]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _busy = true);
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await userRepository.saveProfile(widget.profile.copyWith(
        name: _name.text.trim(),
        age: int.parse(_age.text.trim()),
        weightKg: double.parse(_weight.text.trim()),
        heightCm: double.parse(_height.text.trim()),
        gender: _gender,
        level: _level,
      ));
      setState(() {
        _busy = false;
        _saved = true;
      });
      messenger.showSnackBar(const SnackBar(content: Text('Profile updated'), duration: Duration(seconds: 2)));
      await Future.delayed(const Duration(milliseconds: 700));
      navigator.pop();
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Could not save: $e')));
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    Widget stagger(int i, Widget child) => Entrance(delay: Motion.stagger(i, stepMs: 50), child: child);
    Widget numberField(TextEditingController c, String label, String? Function(String?) v) => LabeledField(
          label: label,
          child: TextFormField(
            controller: c,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(errorMaxLines: 3),
            validator: v,
            onChanged: (_) => setState(() => _saved = false),
          ),
        );

    return Scaffold(
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
                  children: [
                    stagger(0, const Row(children: [
                      AppBackButton(),
                      SizedBox(width: 12),
                      Text('Edit profile', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
                    ])),
                    const SizedBox(height: 18),
                    stagger(1, Center(child: InitialAvatar(name: _name.text, size: 88))),
                    const SizedBox(height: 18),
                    stagger(2, LabeledField(
                      label: 'Name',
                      child: TextFormField(
                        controller: _name,
                        textCapitalization: TextCapitalization.words,
                        validator: Validators.name,
                        onChanged: (_) => setState(() => _saved = false),
                      ),
                    )),
                    const SizedBox(height: 14),
                    stagger(3, Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Expanded(child: numberField(_age, 'Age', Validators.number(label: 'Age', min: 10, max: 100))),
                      const SizedBox(width: 10),
                      Expanded(child: numberField(_weight, 'Weight · kg', Validators.number(label: 'Weight', min: 25, max: 300))),
                      const SizedBox(width: 10),
                      Expanded(child: numberField(_height, 'Height · cm', Validators.number(label: 'Height', min: 100, max: 250))),
                    ])),
                    const SizedBox(height: 18),
                    stagger(4, LabeledField(
                      label: 'Gender',
                      child: SegmentedPill<Gender>(
                        options: const [(Gender.female, 'Female'), (Gender.male, 'Male')],
                        value: _gender,
                        onChanged: (g) => setState(() {
                          _gender = g;
                          _saved = false;
                        }),
                      ),
                    )),
                    const SizedBox(height: 18),
                    stagger(5, LabeledField(
                      label: 'Fitness level',
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        SegmentedPill<Level>(
                          options: [for (final l in Level.values) (l, l.label)],
                          value: _level,
                          onChanged: (l) => setState(() {
                            _level = l;
                            _saved = false;
                          }),
                        ),
                        const SizedBox(height: 8),
                        Text('${_level.repsPerSet} reps per set, ${Level.setsPerWorkout} sets per workout',
                            style: const TextStyle(fontSize: 12, color: AppColors.muted)),
                      ]),
                    )),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
                child: PrimaryButton(
                  label: _saved ? 'Saved' : 'Save changes',
                  icon: _saved ? Icons.check_rounded : null,
                  color: _saved ? AppColors.success : null,
                  busy: _busy,
                  onPressed: _saved ? () {} : _save,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
