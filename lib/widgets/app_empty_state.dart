import 'package:flutter/material.dart';

class AppEmptyState extends StatelessWidget {
  final String message;

  const AppEmptyState({
    super.key,
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        message,
        textAlign: TextAlign.center,
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: Color(0xFF1E4D8F),
        ),
      ),
    );
  }
}