import 'package:easy_localization/easy_localization.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:logger/logger.dart';

import '../../interfaces/i_auth_service.dart';
import '../../service_locator.dart';
import '../common/adaptive_sheet.dart';
import 'password_error_message.dart';
import 'password_sheet_body.dart';

/// Sets a password and links it to the signed-in account.
class AddPasswordForm extends StatefulWidget {
  /// Firebase rejects shorter passwords.
  static const int minPasswordLength = 6;

  final IAuthService authService;

  /// The account's email; asked for only when the account has none.
  final String? email;

  const AddPasswordForm({super.key, required this.authService, this.email});

  /// Resolves to true once the password was linked.
  static Future<bool> show(
    BuildContext context, {
    required IAuthService authService,
    String? email,
  }) async =>
      await AdaptiveSheet.show<bool>(
        context,
        builder: (_) => AddPasswordForm(authService: authService, email: email),
      ) ??
      false;

  @override
  State<AddPasswordForm> createState() => _AddPasswordFormState();
}

class _AddPasswordFormState extends State<AddPasswordForm> {
  final _formKey = GlobalKey<FormState>();
  late final _email = TextEditingController(text: widget.email);
  final _password = TextEditingController();
  final _confirmation = TextEditingController();
  bool _busy = false;
  String? _error;

  bool get _hasAccountEmail => widget.email?.isNotEmpty ?? false;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _confirmation.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_busy || !_formKey.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.authService.linkPasswordCredential(
        email: _email.text.trim(),
        // Sign-in trims the password, so the stored one must match.
        password: _password.text.trim(),
      );
      if (mounted) Navigator.of(context).pop(true);
    } catch (error) {
      final code = error is FirebaseAuthException
          ? error.code
          : error.runtimeType.toString();
      getIt<Logger>().w('Could not add a password: $code');
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
    return Form(
      key: _formKey,
      child: PasswordSheetBody(
        title: 'settings.password.add'.tr(),
        description: 'settings.password.addDescription'.tr(),
        error: _error,
        submitLabel: 'common.save'.tr(),
        busy: _busy,
        onSubmit: _submit,
        fields: [
          TextFormField(
            controller: _email,
            readOnly: _hasAccountEmail,
            keyboardType: TextInputType.emailAddress,
            decoration: InputDecoration(
              labelText: 'auth.form.email.label'.tr(),
            ),
            validator: (value) {
              final email = value?.trim() ?? '';
              if (email.isEmpty) return 'auth.form.email.required'.tr();
              if (!email.contains('@')) return 'auth.error.invalid_email'.tr();
              return null;
            },
          ),
          TextFormField(
            controller: _password,
            obscureText: true,
            autofillHints: const [AutofillHints.newPassword],
            decoration: InputDecoration(
              labelText: 'settings.password.newPassword'.tr(),
            ),
            validator: (value) =>
                (value?.trim().length ?? 0) < AddPasswordForm.minPasswordLength
                ? 'settings.password.tooShort'.tr(
                    namedArgs: {
                      'count': '${AddPasswordForm.minPasswordLength}',
                    },
                  )
                : null,
          ),
          TextFormField(
            controller: _confirmation,
            obscureText: true,
            decoration: InputDecoration(
              labelText: 'settings.password.confirm'.tr(),
            ),
            validator: (value) => value?.trim() != _password.text.trim()
                ? 'settings.password.mismatch'.tr()
                : null,
            onFieldSubmitted: (_) => _submit(),
          ),
        ],
      ),
    );
  }
}
