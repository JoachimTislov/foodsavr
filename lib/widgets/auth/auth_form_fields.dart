import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

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

class _AuthFormFieldsState extends State<AuthFormFields> {
  bool _isPasswordVisible = false;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Email Input
        TextFormField(
          controller: widget.emailController,
          decoration: InputDecoration(
            labelText: 'Email Address'.tr(),
            hintText: 'name@example.com'.tr(),
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
              return 'Please enter your email'.tr();
            }
            return null;
          },
        ),
        const SizedBox(height: 16.0),

        // Password Input
        TextFormField(
          controller: widget.passwordController,
          obscureText: !_isPasswordVisible,
          decoration: InputDecoration(
            labelText: 'Password'.tr(),
            hintText: 'Enter your password'.tr(),
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
                _isPasswordVisible ? Icons.visibility : Icons.visibility_off,
              ),
              onPressed: () {
                setState(() {
                  _isPasswordVisible = !_isPasswordVisible;
                });
              },
            ),
          ),
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Please enter your password'.tr();
            }
            return null;
          },
        ),
      ],
    );
  }
}
