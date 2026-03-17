import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:watch_it/watch_it.dart';

class AuthFormFields extends WatchingWidget {
  final TextEditingController emailController;
  final TextEditingController passwordController;

  const AuthFormFields({
    super.key,
    required this.emailController,
    required this.passwordController,
  });

  @override
  Widget build(BuildContext context) {
    final isPasswordVisible = createOnce(() => ValueNotifier<bool>(false));
    final passwordVisible = watch(isPasswordVisible).value;

    return Column(
      children: [
        TextFormField(
          controller: emailController,
          decoration: InputDecoration(
            labelText: 'auth.form.email'.tr(),
            hintText: 'auth.form.email_hint'.tr(),
            prefixIcon: const Icon(Icons.email_outlined),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
          keyboardType: TextInputType.emailAddress,
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'auth.validation.email_required'.tr();
            }
            if (!value.contains('@')) {
              return 'auth.validation.email_invalid'.tr();
            }
            return null;
          },
        ),
        const SizedBox(height: 16.0),
        TextFormField(
          controller: passwordController,
          decoration: InputDecoration(
            labelText: 'auth.form.password'.tr(),
            hintText: 'auth.form.password_hint'.tr(),
            prefixIcon: const Icon(Icons.lock_outline),
            suffixIcon: IconButton(
              icon: Icon(
                passwordVisible ? Icons.visibility : Icons.visibility_off,
              ),
              onPressed: () => isPasswordVisible.value = !passwordVisible,
            ),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
          obscureText: !passwordVisible,
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'auth.validation.password_required'.tr();
            }
            if (value.length < 6) {
              return 'auth.validation.password_too_short'.tr();
            }
            return null;
          },
        ),
      ],
    );
  }
}
