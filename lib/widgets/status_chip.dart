import 'package:flutter/material.dart';

class StatusChip extends StatelessWidget {

  final String status;

  const StatusChip({super.key, required this.status});

  @override
  Widget build(BuildContext context) {

    Color color = Colors.orange;

    if(status=="APPROVED") color = Colors.green;
    if(status=="REJECTED") color = Colors.red;

    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: 10,
          vertical: 4
      ),

      decoration: BoxDecoration(
        color: color.withOpacity(.15),
        borderRadius: BorderRadius.circular(20),
      ),

      child: Text(
        status,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}