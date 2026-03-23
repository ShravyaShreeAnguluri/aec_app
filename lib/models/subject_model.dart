class SubjectModel {
  final String id;
  final String name;
  final String code;
  final int year;
  final String department;
  final int semester;
  final String description;

  const SubjectModel({
    required this.id,
    required this.name,
    required this.code,
    required this.year,
    required this.department,
    required this.semester,
    required this.description,
  });

  factory SubjectModel.fromJson(Map<String, dynamic> j) => SubjectModel(
    id: (j['id'] ?? '').toString(), // ✅ changed from _id
    name: (j['name'] ?? '').toString(),
    code: (j['code'] ?? '').toString(),
    year: (j['year'] as num?)?.toInt() ?? 1,
    department: (j['department'] ?? '').toString(),
    semester: (j['semester'] as num?)?.toInt() ?? 1,
    description: (j['description'] ?? '').toString(),
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'code': code,
    'year': year,
    'department': department,
    'semester': semester,
    'description': description,
  };

  String get display => '$code – $name';
}