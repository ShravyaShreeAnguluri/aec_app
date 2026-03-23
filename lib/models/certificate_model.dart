class CertificateModel {
  final String id;
  final String title;
  final String facultyName;
  final String department;
  final String type;
  final String issuedBy;
  final String issueDate;
  final String fileName;
  final String originalName;
  final String fileType;
  final int fileSize;
  final String filePath;
  final DateTime createdAt;

  const CertificateModel({
    required this.id,
    required this.title,
    required this.facultyName,
    required this.department,
    required this.type,
    required this.issuedBy,
    required this.issueDate,
    required this.fileName,
    required this.originalName,
    required this.fileType,
    required this.fileSize,
    required this.filePath,
    required this.createdAt,
  });

  factory CertificateModel.fromJson(Map<String, dynamic> j) => CertificateModel(
    id: (j['id'] ?? '').toString(), // ✅ changed from _id
    title: (j['title'] ?? '').toString(),
    facultyName: (j['facultyName'] ?? '').toString(),
    department: (j['department'] ?? '').toString(),
    type: (j['type'] ?? 'Faculty Achievement').toString(),
    issuedBy: (j['issuedBy'] ?? '').toString(),
    issueDate: (j['issueDate'] ?? '').toString(),
    fileName: (j['fileName'] ?? '').toString(),
    originalName: (j['originalName'] ?? '').toString(),
    fileType: (j['fileType'] ?? 'pdf').toString(),
    fileSize: (j['fileSize'] as num?)?.toInt() ?? 0,
    filePath: (j['filePath'] ?? '').toString(),
    createdAt: DateTime.tryParse((j['createdAt'] ?? '').toString()) ?? DateTime.now(),
  );

  bool get isAchievement => type == 'Faculty Achievement';

  String get formattedSize {
    if (fileSize < 1024 * 1024) {
      return '${(fileSize / 1024).toStringAsFixed(1)} KB';
    }
    return '${(fileSize / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}