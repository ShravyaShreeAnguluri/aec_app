import 'package:flutter/material.dart';

import '../../services/api_service.dart';

class NotificationScreen extends StatefulWidget {
  const NotificationScreen({super.key});

  @override
  State<NotificationScreen> createState() => _NotificationScreenState();
}

class _NotificationScreenState extends State<NotificationScreen> {

  List notifications = [];

  @override
  void initState() {
    super.initState();
    loadNotifications();
  }

  Future loadNotifications() async {

    final data = await ApiService.getNotifications();

    setState(() {
      notifications = data;
    });

  }

  @override
  Widget build(BuildContext context) {

    return Scaffold(

      appBar: AppBar(title: const Text("Notifications")),

      body: ListView.builder(
        itemCount: notifications.length,
        itemBuilder: (context,index){

          final n = notifications[index];

          return ListTile(
            leading: const Icon(Icons.notifications),
            title: Text(n["message"]),
          );

        },
      ),

    );

  }
}