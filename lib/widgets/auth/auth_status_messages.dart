import 'package:flutter/material.dart';

class AuthStatusMessages extends StatefulWidget {
  final String? errorMessage;
  final String? successMessage;

  const AuthStatusMessages({super.key, this.errorMessage, this.successMessage});

  @override
  State<AuthStatusMessages> createState() => _AuthStatusMessagesState();
}

class _AuthStatusMessagesState extends State<AuthStatusMessages> {
  @override
  void didUpdateWidget(AuthStatusMessages oldWidget) {
    super.didUpdateWidget(oldWidget);
    final appeared =
        (widget.errorMessage != null &&
            widget.errorMessage != oldWidget.errorMessage) ||
        (widget.successMessage != null &&
            widget.successMessage != oldWidget.successMessage);
    if (!appeared) return;
    // The buttons that trigger a message can sit below the fold.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        Scrollable.ensureVisible(
          context,
          duration: const Duration(milliseconds: 200),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final errorMessage = widget.errorMessage;
    final successMessage = widget.successMessage;
    final colorScheme = Theme.of(context).colorScheme;

    if ((errorMessage == null || errorMessage.isEmpty) &&
        (successMessage == null || successMessage.isEmpty)) {
      return const SizedBox.shrink();
    }

    return Semantics(
      container: true,
      liveRegion: true,
      child: Column(
        children: [
          if (errorMessage != null && errorMessage.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 16.0),
              child: Text(
                errorMessage,
                style: TextStyle(color: colorScheme.error),
                textAlign: TextAlign.center,
              ),
            ),
          if (successMessage != null && successMessage.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 16.0),
              child: Text(
                successMessage,
                style: TextStyle(color: colorScheme.primary),
                textAlign: TextAlign.center,
              ),
            ),
        ],
      ),
    );
  }
}
