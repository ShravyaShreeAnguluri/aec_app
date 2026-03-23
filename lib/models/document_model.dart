class DocumentModel {
  final String id;
  final String title;
  final String description;
  final String fileName;
  final String originalName;
  final String fileType;
  final int fileSize;
  final String filePath;
  final int year;
  final String department;
  final String subjectId;
  final String subjectName;
  final String category;
  final String uploadedBy;
  final int downloadCount;
  final DateTime createdAt;

  const DocumentModel({
    required this.id,
    required this.title,
    required this.description,
    required this.fileName,
    required this.originalName,
    required this.fileType,
    required this.fileSize,
    required this.filePath,
    required this.year,
    required this.department,
    required this.subjectId,
    required this.subjectName,
    required this.category,
    required this.uploadedBy,
    required this.downloadCount,
    required this.createdAt,
  });

  factory DocumentModel.fromJson(Map<String, dynamic> j) => DocumentModel(
    id: (j['id'] ?? '').toString(), // ✅ changed from _id
    title: (j['title'] ?? '').toString(),
    description: (j['description'] ?? '').toString(),
    fileName: (j['fileName'] ?? '').toString(),
    originalName: (j['originalName'] ?? '').toString(),
    fileType: (j['fileType'] ?? 'other').toString(),
    fileSize: (j['fileSize'] as num?)?.toInt() ?? 0,
    filePath: (j['filePath'] ?? '').toString(),
    year: (j['year'] as num?)?.toInt() ?? 1,
    department: (j['department'] ?? '').toString(),

    // ✅ backend now sends subject as plain value/string
    subjectId: (j['subject'] ?? '').toString(),

    subjectName: (j['subjectName'] ?? '').toString(),
    category: (j['category'] ?? 'Lecture Notes').toString(),
    uploadedBy: (j['uploadedBy'] ?? 'Faculty').toString(),
    downloadCount: (j['downloadCount'] as num?)?.toInt() ?? 0,
    createdAt: DateTime.tryParse((j['createdAt'] ?? '').toString()) ?? DateTime.now(),
  );

  String get formattedSize {
    if (fileSize < 1024) return '$fileSize B';
    if (fileSize < 1024 * 1024) {
      return '${(fileSize / 1024).toStringAsFixed(1)} KB';
    }
    return '${(fileSize / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  String get shortDate {
    final now = DateTime.now();
    final diff = now.difference(createdAt).inDays;
    if (diff == 0) return 'Today';
    if (diff == 1) return 'Yesterday';
    if (diff < 7) return '${diff}d ago';
    const m = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${createdAt.day} ${m[createdAt.month - 1]}';
  }
}