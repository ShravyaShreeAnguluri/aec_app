import 'package:flutter/material.dart';

import '../../services/api_service.dart';


class AdminFacultyScreen extends StatefulWidget {
  const AdminFacultyScreen({super.key});

  @override
  State<AdminFacultyScreen> createState() => _AdminFacultyScreenState();
}

class _AdminFacultyScreenState extends State<AdminFacultyScreen> {

  List facultyList = [];
  bool loading = true;

  @override
  void initState() {
    super.initState();
    loadFaculty();
  }

  Future<void> loadFaculty() async {

    final data = await ApiService.getFacultyList();

    setState(() {
      facultyList = data;
      loading = false;
    });
  }
  Map<String, List<dynamic>> groupByDepartment(List facultyList) {

    Map<String, List<dynamic>> grouped = {};

    for (var faculty in facultyList) {

      String dept = faculty["department"];

      if (!grouped.containsKey(dept)) {
        grouped[dept] = [];
      }

      grouped[dept]!.add(faculty);
    }

    return grouped;
  }

  @override
  Widget build(BuildContext context) {

    return Scaffold(

      appBar: AppBar(
        title: const Text("Faculty Management"),
      ),

      body: loading
          ? const Center(child: CircularProgressIndicator())
          : Builder(
        builder: (context) {

          final grouped = groupByDepartment(facultyList);

          return ListView(
            children: grouped.entries.map((entry) {

              String department = entry.key;
              List users = entry.value;

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [

                  /// Department title
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: Text(
                      department,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),

                  /// Faculty inside department
                  ...users.map((user) {

                    return Card(
                      margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),

                      child: ListTile(
                        title: Text(user["name"]),
                        subtitle: Text(user["department"]),

                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [

                              /// Make HOD
                              if (user["role"] == "faculty")
                                ElevatedButton(
                                  child: const Text("HOD"),
                                  onPressed: () async {

                                    try {

                                      await ApiService.upgradeToHod(user["faculty_id"]);

                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(content: Text("Faculty upgraded to HOD")),
                                      );

                                      loadFaculty();

                                    } catch (e) {

                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(content: Text(e.toString())),
                                      );

                                    }

                                  },
                                ),

                              const SizedBox(width: 6),

                              /// Make Dean
                              if (user["role"] != "admin")
                                ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.deepPurple,
                                  ),
                                  child: const Text("Dean"),
                                  onPressed: () async {

                                    try {

                                      await ApiService.upgradeToDean(user["faculty_id"]);

                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(content: Text("Faculty promoted to Dean")),
                                      );

                                      loadFaculty();

                                    } catch (e) {

                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(content: Text(e.toString())),
                                      );

                                    }

                                  },
                                ),

                              const SizedBox(width: 10),

                              Text(
                                user["role"].toUpperCase(),
                                style: const TextStyle(fontWeight: FontWeight.bold),
                              ),

                            ],
                          ),
                      ),
                    );

                  }).toList(),

                ],
              );

            }).toList(),
          );
        },
      ),
    );
  }
}