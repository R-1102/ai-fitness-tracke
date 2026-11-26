import 'package:flutter/material.dart';

import '../../core/motion.dart';
import '../../core/theme.dart';
import '../../services/auth_service.dart';
import '../../services/services.dart';
import '../../widgets/ui.dart';
import 'edit_profile_screen.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  Future<void> _deleteAccount(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.xl)),
        title: const Text('Delete account?', style: TextStyle(fontWeight: FontWeight.w800)),
        content: const Text('This permanently deletes your profile and workout history. This cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: AppColors.danger),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    // Firebase only lets you delete an account shortly after signing in.
    // Check first, so we never wipe the data but fail to delete the account.
    final user = authService.currentUser!;
    final lastSignIn = user.metadata.lastSignInTime;
    if (lastSignIn == null || DateTime.now().difference(lastSignIn) > const Duration(minutes: 5)) {
      messenger.showSnackBar(const SnackBar(content: Text('For security, log out and log in again, then delete your account.')));
      return;
    }
    try {
      await userRepository.deleteAllData(user.uid);
      await authService.deleteAccount();
    } on AuthFailure catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Could not delete account: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = ProfileScope.of(context);
    final bmi = p.bmi;
    Widget stagger(int i, Widget child) => Entrance(delay: Motion.stagger(i, stepMs: 70), child: child);
    void openEdit() => Navigator.of(context).push(scopedRoute(context, EditProfileScreen(profile: p)));

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        children: [
          stagger(0, Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(color: AppColors.ink, borderRadius: BorderRadius.circular(AppRadius.xl)),
            child: Row(children: [
              InitialAvatar(name: p.name, size: 64),
              const SizedBox(width: 14),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(p.name, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: Colors.white), overflow: TextOverflow.ellipsis),
                  Text(p.email, style: const TextStyle(fontSize: 13, color: AppColors.onNavyMuted), overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 6),
                  Pill(p.levelOrDefault.label, background: AppColors.accent, foreground: Colors.white, bordered: false),
                ]),
              ),
              SquareIconButton(
                icon: Icons.edit_outlined,
                tooltip: 'Edit profile',
                background: const Color(0xFF1C2D45),
                foreground: Colors.white,
                bordered: false,
                onPressed: openEdit,
              ),
            ]),
          )),
          const SizedBox(height: 16),
          stagger(1, Row(children: [
            Expanded(child: StatTile(center: true, label: 'cm', value: Text(p.heightCm?.toStringAsFixed(0) ?? '–'))),
            const SizedBox(width: 8),
            Expanded(child: StatTile(center: true, label: 'kg', value: Text(p.weightKg?.toStringAsFixed(0) ?? '–'))),
            const SizedBox(width: 8),
            Expanded(child: StatTile(center: true, label: 'years', value: Text('${p.age ?? '–'}'))),
            const SizedBox(width: 8),
            Expanded(child: StatTile(center: true, label: 'BMI', value: Text(bmi == null ? '–' : bmi.toStringAsFixed(1)))),
          ])),
          const SizedBox(height: 16),
          stagger(2, _Group(children: [
            _SettingRow(
              icon: Icons.record_voice_over_outlined,
              title: 'Voice coaching',
              subtitle: 'Hear rep counts and form tips',
              trailing: Switch(
                value: p.voiceCoaching,
                onChanged: (v) => userRepository.saveProfile(p.copyWith(voiceCoaching: v)),
              ),
            ),
            const _SettingRow(
              icon: Icons.shield_outlined,
              iconColor: AppColors.success,
              iconBackground: AppColors.successSoft,
              title: 'Privacy',
              subtitle: 'Camera video never leaves your phone',
            ),
          ])),
          const SizedBox(height: 16),
          stagger(3, _Group(children: [
            _ActionRow(label: 'Edit profile', icon: Icons.chevron_right_rounded, onTap: openEdit),
            _ActionRow(label: 'Log out', icon: Icons.logout_rounded, onTap: authService.signOut),
            _ActionRow(label: 'Delete account', color: AppColors.danger, onTap: () => _deleteAccount(context)),
          ])),
        ],
      ),
    );
  }
}

class _Group extends StatelessWidget {
  const _Group({required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Card(
        clipBehavior: Clip.antiAlias,
        child: Column(children: [
          for (final (i, c) in children.indexed) ...[
            if (i > 0) const Divider(height: 1, thickness: 1, color: AppColors.divider),
            c,
          ],
        ]),
      );
}

class _SettingRow extends StatelessWidget {
  const _SettingRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.trailing,
    this.iconColor = AppColors.accentDark,
    this.iconBackground = AppColors.accentSoft,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Widget? trailing;
  final Color iconColor;
  final Color iconBackground;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(children: [
          SoftIcon(icon: icon, color: iconColor, background: iconBackground, size: 36),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
              Text(subtitle, style: const TextStyle(fontSize: 12, color: AppColors.muted)),
            ]),
          ),
          if (trailing != null) trailing!,
        ]),
      );
}

class _ActionRow extends StatelessWidget {
  const _ActionRow({required this.label, required this.onTap, this.icon, this.color = AppColors.ink});
  final String label;
  final VoidCallback onTap;
  final IconData? icon;
  final Color color;

  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        child: SizedBox(
          height: 56,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(children: [
              Expanded(child: Text(label, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: color))),
              if (icon != null) Icon(icon, size: 20, color: AppColors.subtle),
            ]),
          ),
        ),
      );
}
