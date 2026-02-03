import 'package:flutter/material.dart';

class AuthSubmitButton extends StatelessWidget {
  final bool isLogin;
  final VoidCallback onPressed;

  const AuthSubmitButton({
    super.key,
    required this.isLogin,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return FilledButton(
      style: FilledButton.styleFrom(minimumSize: Size(double.infinity, 50)),
      onPressed: onPressed,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(isLogin ? 'Login' : 'Register'),
          Icon(Icons.arrow_right_alt),
        ],
      ),
    );
  }
}
