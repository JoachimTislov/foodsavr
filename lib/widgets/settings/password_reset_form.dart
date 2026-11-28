import 'package:easy_localization/easy_localization.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:logger/logger.dart';

import '../../interfaces/i_auth_service.dart';
import '../../service_locator.dart';
import '../common/adaptive_sheet.dart';
import 'password_error_message.dart';
import 'password_sheet_body.dart';

/// Emails a password reset link.
class PasswordResetForm extends StatefulWidget {
  final IAuthService authService;
  final String? email;

  const PasswordResetForm({super.key, required this.authService, this.email});

  /// Resolves to true once the email was sent.
  static Future<bool> show(
    BuildContext context, {
    required IAuthService authService,
    String? email,
  }) async =>
      await AdaptiveSheet.show<bool>(
        context,
        builder: (_) =>
            PasswordResetForm(authService: authService, email: email),
      ) ??
      false;

  @override
  State<PasswordResetForm> createState() => _PasswordResetFormState();
}

class _PasswordResetFormState extends State<PasswordResetForm> {
  late final _email = TextEditingController(text: widget.email);
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_busy) return;
    final email = _email.text.trim();
    if (email.isEmpty) {
      setState(() => _error = 'auth.reset.email_prompt'.tr());
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.authService.sendPasswordResetEmail(email);
      if (mounted) Navigator.of(context).pop(true);
    } catch (error) {
      final code = error is FirebaseAuthException
          ? error.code
          : error.runtimeType.toString();
      getIt<Logger>().w('Could not send a password reset email: $code');
      if (mounted) {
        setState(() {
          _busy = false;
          _error = passwordErrorMessage(error);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return PasswordSheetBody(
      title: 'profile.forgot_password'.tr(),
      error: _error,
      submitLabel: 'settings.password.sendLink'.tr(),
      busy: _busy,
      onSubmit: _submit,
      fields: [
        TextField(
          controller: _email,
          keyboardType: TextInputType.emailAddress,
          decoration: InputDecoration(
            labelText: 'auth.form.email.label'.tr(),
            hintText: 'auth.form.email.hint'.tr(),
          ),
          onSubmitted: (_) => _submit(),
        ),
      ],
    );
  }
}
