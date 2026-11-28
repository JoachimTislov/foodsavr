import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:watch_it/watch_it.dart';

import '../constants/public_routes.dart';
import '../controllers/user_controller.dart';
import '../widgets/common/content_constraint.dart';
import '../widgets/settings/password_action_tile.dart';
import '../widgets/settings/settings_section.dart';

class ProfileView extends WatchingWidget {
  const ProfileView({super.key});

  @override
  Widget build(BuildContext context) {
    final authController = watchIt<UserController>();
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          tooltip: MaterialLocalizations.of(context).backButtonTooltip,
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/dashboard');
            }
          },
        ),
        title: Text(
          'profile.title'.tr(),
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      body: CustomScrollView(
        slivers: [
          SliverContentConstraint(
            maxWidth: SettingsSection.maxContentWidth,
            slivers: [
              SliverToBoxAdapter(
                child: _ProfileHeader(
                  name: authController.displayName,
                  email: authController.email,
                  avatarUrl: authController.photoUrl,
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.all(24),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    const SizedBox(height: 32),
                    Text(
                      'profile.account_settings'.tr(),
                      style: textTheme.labelSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.2,
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 16),
                    _SettingsGroup(
                      items: [
                        if (authController.isAnonymous)
                          _SettingsItem(
                            icon: Icons.person_add_alt_1_outlined,
                            label: 'profile.create_account'.tr(),
                            onTap: () => context.go('/auth?mode=signup'),
                          ),
                        if (PasswordActionTile.appliesTo(authController.user))
                          PasswordActionTile(),
                        _SettingsItem(
                          icon: Icons.mail_outline,
                          label: 'profile.change_email'.tr(),
                          onTap: () =>
                              _showChangeEmailSheet(context, authController),
                        ),
                        _SettingsItem(
                          icon: Icons.logout,
                          label: 'profile.log_out'.tr(),
                          isDestructive: true,
                          onTap: () => authController.signOut(),
                        ),
                      ],
                    ),
                    const SizedBox(height: 32),
                    Text(
                      'profile.danger_zone'.tr(),
                      style: textTheme.labelSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.2,
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                    const SizedBox(height: 16),
                    _SettingsGroup(
                      items: [
                        _SettingsItem(
                          icon: Icons.delete_outline,
                          label: 'profile.delete_account'.tr(),
                          isDestructive: true,
                          onTap: () => context.push(PublicRoutes.deleteAccount),
                        ),
                      ],
                    ),
                  ]),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showActionResult(BuildContext context, UserController controller) {
    final success = controller.successMessage;
    final error = controller.errorMessage;
    if (success == null && error == null) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(success ?? error!)));
  }

  void _showChangeEmailSheet(BuildContext context, UserController controller) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(sheetContext).viewInsets.bottom,
        ),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Theme.of(sheetContext).colorScheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
          ),
          child: _ChangeEmailSheetFields(
            controller: controller,
            onCompleted: () {
              Navigator.pop(sheetContext);
              if (context.mounted) {
                _showActionResult(context, controller);
              }
            },
          ),
        ),
      ),
    );
  }
}

class _ProfileHeader extends StatelessWidget {
  final String name;
  final String? _email;
  final String? avatarUrl;

  const _ProfileHeader({required this.name, email, this.avatarUrl})
    : _email = email;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Container(
      padding: const EdgeInsets.only(left: 24, top: 32, right: 24, bottom: 32),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainer,
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(32)),
      ),
      child: Column(
        children: [
          CircleAvatar(
            radius: 56,
            backgroundColor: colorScheme.outlineVariant,
            backgroundImage: avatarUrl != null
                ? NetworkImage(avatarUrl!) as ImageProvider
                : null,
            child: avatarUrl == null
                ? Icon(
                    Icons.person,
                    size: 56,
                    color: colorScheme.onSurfaceVariant,
                  )
                : null,
          ),
          const SizedBox(height: 16),
          Text(
            name,
            style: textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          if (_email != null)
            Text(
              _email,
              style: textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
        ],
      ),
    );
  }
}

class _SettingsGroup extends StatelessWidget {
  final List<Widget> items;

  const _SettingsGroup({required this.items});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Material(
      color: colorScheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: colorScheme.outlineVariant.withValues(alpha: 0.1),
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          for (int i = 0; i < items.length; i++) ...[
            if (i > 0)
              Divider(
                height: 1,
                indent: 64,
                endIndent: 16,
                color: colorScheme.outlineVariant.withValues(alpha: 0.1),
              ),
            items[i],
          ],
        ],
      ),
    );
  }
}

class _SettingsItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final bool isDestructive;

  const _SettingsItem({
    required this.icon,
    required this.label,
    this.onTap,
    this.isDestructive = false,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    final color = isDestructive ? colorScheme.error : colorScheme.onSurface;

    return ListTile(
      onTap: onTap,
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: isDestructive
              ? colorScheme.errorContainer
              : colorScheme.surfaceContainer,
          shape: BoxShape.circle,
        ),
        child: Icon(icon, size: 20, color: color),
      ),
      title: Text(
        label,
        style: textTheme.bodyLarge?.copyWith(
          color: color,
          fontWeight: FontWeight.w500,
        ),
      ),
      trailing: null,
    );
  }
}

class _ChangeEmailSheetFields extends StatefulWidget {
  const _ChangeEmailSheetFields({
    required this.controller,
    required this.onCompleted,
  });

  final UserController controller;
  final VoidCallback onCompleted;

  @override
  State<_ChangeEmailSheetFields> createState() =>
      _ChangeEmailSheetFieldsState();
}

class _ChangeEmailSheetFieldsState extends State<_ChangeEmailSheetFields> {
  final _passwordController = TextEditingController();
  final _emailController = TextEditingController();

  @override
  void dispose() {
    _passwordController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'profile.change_email'.tr(),
          style: Theme.of(
            context,
          ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _passwordController,
          obscureText: true,
          decoration: InputDecoration(
            labelText: 'auth.form.password.label'.tr(),
            hintText: 'auth.form.password.hint'.tr(),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _emailController,
          keyboardType: TextInputType.emailAddress,
          decoration: InputDecoration(
            labelText: 'profile.new_email'.tr(),
            hintText: 'auth.form.email.hint'.tr(),
          ),
        ),
        const SizedBox(height: 24),
        ListenableBuilder(
          listenable: widget.controller,
          builder: (context, _) => ElevatedButton(
            onPressed: widget.controller.isLoading
                ? null
                : () async {
                    await widget.controller.changeEmail(
                      currentPassword: _passwordController.text,
                      newEmail: _emailController.text,
                    );
                    if (mounted) widget.onCompleted();
                  },
            style: ElevatedButton.styleFrom(
              minimumSize: const Size.fromHeight(56),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            child: Text('common.save'.tr()),
          ),
        ),
        const SizedBox(height: 12),
        TextButton(
          onPressed: () => Navigator.pop(context),
          style: TextButton.styleFrom(minimumSize: const Size.fromHeight(56)),
          child: Text('common.cancel'.tr()),
        ),
      ],
    );
  }
}
