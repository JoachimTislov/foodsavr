import 'package:flutter/material.dart';

class AuthStatusMessages extends StatelessWidget {
  final String? errorMessage;
  final String? successMessage;

  const AuthStatusMessages({super.key, this.errorMessage, this.successMessage});

  @override
  Widget build(BuildContext context) {
    if ((errorMessage == null || errorMessage!.isEmpty) &&
        (successMessage == null || successMessage!.isEmpty)) {
      return const SizedBox.shrink();
    }

    return Column(
      children: [
        if (errorMessage != null && errorMessage!.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 16.0),
            child: Text(
              errorMessage!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
              textAlign: TextAlign.center,
            ),
          ),
        if (successMessage != null && successMessage!.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 16.0),
            child: Text(
              successMessage!,
              style: TextStyle(color: Theme.of(context).colorScheme.primary),
              textAlign: TextAlign.center,
            ),
          ),
      ],
    );
  }
}
