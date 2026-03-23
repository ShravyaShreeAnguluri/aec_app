import 'package:flutter/material.dart';

class EditProfileScreen extends StatefulWidget {
  final String name;
  final String? designation;
  final String? qualification;

  const EditProfileScreen({
    super.key,
    required this.name,
    this.designation,
    this.qualification,
  });

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {

  late TextEditingController nameController;
  late TextEditingController designationController;
  late TextEditingController qualificationController;

  @override
  void initState() {
    super.initState();
    nameController = TextEditingController(text: widget.name);
    designationController =
        TextEditingController(text: widget.designation ?? "");
    qualificationController =
        TextEditingController(text: widget.qualification ?? "");
  }

  void saveProfile() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Profile Updated")),
    );

    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Edit Profile"),
        backgroundColor: const Color(0xFF1E4D8F),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [

            TextField(
              controller: nameController,
              decoration: const InputDecoration(labelText: "Name"),
            ),

            TextField(
              controller: designationController,
              decoration: const InputDecoration(labelText: "Designation"),
            ),

            TextField(
              controller: qualificationController,
              decoration: const InputDecoration(labelText: "Qualification"),
            ),

            const SizedBox(height: 30),

            ElevatedButton(
              onPressed: saveProfile,
              child: const Text("Save Changes"),
            )
          ],
        ),
      ),
    );
  }
}
