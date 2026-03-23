
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../faculty_docs_screens/certificates_screen.dart';
import '../faculty_docs_screens/home_screen.dart';
import '../providers/certificate_provider.dart';
import '../providers/document_provider.dart';

class FacultyDocsQuickAccess extends StatelessWidget {
  const FacultyDocsQuickAccess({super.key});

  void _openDocs(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => MultiProvider(
          providers: [
            ChangeNotifierProvider(create: (_) => DocumentProvider()),
            ChangeNotifierProvider(create: (_) => CertificateProvider()),
          ],
          child: const HomeScreen(),
        ),
      ),
    );
  }

  void _openCerts(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChangeNotifierProvider(
          create: (_) => CertificateProvider(),
          child: const CertificatesScreen(),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section header
        const Padding(
          padding: EdgeInsets.only(bottom: 12),
          child: Text(
            "Quick Access",
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1E4D8F),
            ),
          ),
        ),

        Row(children: [

          // ── Faculty Docs card ────────────────────────────────────────
          Expanded(
            child: GestureDetector(
              onTap: () => _openDocs(context),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E4D8F),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF1E4D8F).withOpacity(0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.folder_open_rounded,
                        color: Colors.white, size: 32),
                    SizedBox(height: 10),
                    Text("Faculty Docs",
                        style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 15)),
                    SizedBox(height: 4),
                    Text("Notes, Assignments\n& Study Material",
                        style: TextStyle(color: Colors.white70, fontSize: 11)),
                  ],
                ),
              ),
            ),
          ),

          const SizedBox(width: 12),

          // ── Certificates card ────────────────────────────────────────
          Expanded(
            child: GestureDetector(
              onTap: () => _openCerts(context),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF7C3AED),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF7C3AED).withOpacity(0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.workspace_premium_rounded,
                        color: Colors.white, size: 32),
                    SizedBox(height: 10),
                    Text("Certificates",
                        style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 15)),
                    SizedBox(height: 4),
                    Text("Achievements &\nTraining Records",
                        style: TextStyle(color: Colors.white70, fontSize: 11)),
                  ],
                ),
              ),
            ),
          ),

        ]),
      ],
    );
  }
}