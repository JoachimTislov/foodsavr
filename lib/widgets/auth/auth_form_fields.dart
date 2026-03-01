import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:watch_it/watch_it.dart';

class AuthFormFields extends StatefulWidget {
  final TextEditingController emailController;
  final TextEditingController passwordController;

  const AuthFormFields({
    super.key,
    required this.emailController,
    required this.passwordController,
  });

  @override
  State<AuthFormFields> createState() => _AuthFormFieldsState();
}

class _AuthFormFieldsState extends State<AuthFormFields>
    with WatchItStatefulWidgetMixin {
  final _isPasswordVisible = ValueNotifier<bool>(false);

  @override
  void dispose() {
    _isPasswordVisible.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isPasswordVisible = watch(_isPasswordVisible).value;
    return Column(
      children: [
        // Email Input
        TextFormField(
          controller: widget.emailController,
          decoration: InputDecoration(
            labelText: 'auth.form.email.label'.tr(),
            hintText: 'auth.form.email.hint'.tr(),
            prefixIcon: const Icon(Icons.mail_outline),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12.0),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12.0),
              borderSide: BorderSide(
                color: Theme.of(context).colorScheme.primary,
                width: 2.0,
              ),
            ),
          ),
          keyboardType: TextInputType.emailAddress,
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'auth.form.email.required'.tr();
            }
            return null;
          },
        ),
        const SizedBox(height: 16.0),

        // Password Input
        TextFormField(
          controller: widget.passwordController,
          obscureText: !isPasswordVisible,
          decoration: InputDecoration(
            labelText: 'auth.form.password.label'.tr(),
            hintText: 'auth.form.password.hint'.tr(),
            prefixIcon: const Icon(Icons.lock_outline),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12.0),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12.0),
              borderSide: BorderSide(
                color: Theme.of(context).colorScheme.primary,
                width: 2.0,
              ),
            ),
            suffixIcon: IconButton(
              icon: Icon(
                isPasswordVisible ? Icons.visibility : Icons.visibility_off,
              ),
              onPressed: () {
                _isPasswordVisible.value = !isPasswordVisible;
              },
            ),
          ),
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'auth.form.password.required'.tr();
            }
            return null;
          },
        ),
      ],
    );
  }
}
