import 'package:flutter/material.dart';

import 'calibration_evidence/evidence_home_page.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const CalibrationEvidenceApp());
}

class CalibrationEvidenceApp extends StatelessWidget {
  const CalibrationEvidenceApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Card Scan Calibration Evidence',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
        useMaterial3: true,
      ),
      home: const EvidenceHomePage(),
    );
  }
}
