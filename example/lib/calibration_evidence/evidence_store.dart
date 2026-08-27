import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:archive/archive_io.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:dxtr_card_scan/dxtr_card_scan.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import 'evidence_models.dart';

class EvidenceStore {
  static const _rootFolderName = 'dxtr_card_scan_calibration';

  Future<Directory> rootDirectory() async {
    final documents = await getApplicationDocumentsDirectory();
    final root = Directory(p.join(documents.path, _rootFolderName));
    await root.create(recursive: true);
    return root;
  }

  Future<Map<String, Object?>> readDeviceMetadata() async {
    final plugin = DeviceInfoPlugin();
    if (Platform.isAndroid) {
      final info = await plugin.androidInfo;
      return <String, Object?>{
        'platform': 'android',
        'manufacturer': info.manufacturer,
        'model': info.model,
        'device': info.device,
        'product': info.product,
        'androidRelease': info.version.release,
        'sdkInt': info.version.sdkInt,
        'physicalDevice': info.isPhysicalDevice,
      };
    }
    if (Platform.isIOS) {
      final info = await plugin.iosInfo;
      return <String, Object?>{
        'platform': 'ios',
        'name': info.name,
        'model': info.model,
        'systemName': info.systemName,
        'systemVersion': info.systemVersion,
        'identifierForVendor': info.identifierForVendor,
        'physicalDevice': info.isPhysicalDevice,
        'utsnameMachine': info.utsname.machine,
      };
    }
    return <String, Object?>{
      'platform': Platform.operatingSystem,
      'operatingSystemVersion': Platform.operatingSystemVersion,
    };
  }

  String suggestedDeviceLabel(Map<String, Object?> metadata) {
    final platform = metadata['platform'];
    if (platform == 'android') {
      final manufacturer = metadata['manufacturer'] ?? '';
      final model = metadata['model'] ?? '';
      return '$manufacturer $model'.trim();
    }
    if (platform == 'ios') {
      return '${metadata['model'] ?? 'iPhone'} (${metadata['utsnameMachine'] ?? ''})'
          .trim();
    }
    return Platform.operatingSystem;
  }

  Future<EvidenceSession> createSession({required String deviceLabel}) async {
    final metadata = await readDeviceMetadata();
    final now = DateTime.now();
    final id = _fileTimestamp(now);
    final session = EvidenceSession(
      id: id,
      deviceLabel: deviceLabel,
      deviceMetadata: metadata,
      createdAt: now,
      samples: const <EvidenceSampleRecord>[],
    );
    await _writeSession(session);
    return session;
  }

  Future<List<EvidenceSession>> loadSessions() async {
    final root = await rootDirectory();
    final sessions = <EvidenceSession>[];
    await for (final entity in root.list()) {
      if (entity is! Directory) continue;
      final manifest = File(p.join(entity.path, 'session.json'));
      if (!await manifest.exists()) continue;
      try {
        final decoded = jsonDecode(await manifest.readAsString());
        sessions.add(
          EvidenceSession.fromJson(Map<String, Object?>.from(decoded as Map)),
        );
      } catch (_) {
        // Keep a malformed/incomplete folder on disk for manual recovery.
      }
    }
    sessions.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return sessions;
  }

  Future<EvidenceSession> saveCapture({
    required EvidenceSession session,
    required EvidenceScenario scenario,
    required CardCaptureResult result,
    String notes = '',
  }) async {
    final sessionDir = await _sessionDirectory(session.id);
    final sampleId = '${scenario.id}_${_fileTimestamp(DateTime.now())}';
    final sampleDir = Directory(p.join(sessionDir.path, 'samples', sampleId));
    await sampleDir.create(recursive: true);

    try {
      final originalName = 'original${_extension(result.original.path)}';
      final croppedName = 'cropped${_extension(result.cropped.path)}';
      final processedName = 'processed${_extension(result.processed.path)}';

      await File(result.original.path).copy(p.join(sampleDir.path, originalName));
      await File(result.cropped.path).copy(p.join(sampleDir.path, croppedName));
      await File(result.processed.path).copy(p.join(sampleDir.path, processedName));

      final quality = await _analyzeQualityOffUiIsolate(
        originalPath: result.original.path,
        croppedPath: result.cropped.path,
      );

      final metadata = <String, Object?>{
        'schemaVersion': 1,
        'protocol': 'v0.3-quality-evidence',
        'sampleId': sampleId,
        'sessionId': session.id,
        'deviceLabel': session.deviceLabel,
        'deviceMetadata': session.deviceMetadata,
        'source': 'Camera',
        'scenario': scenario.id,
        'scenarioGuide': scenario.guide,
        'notes': notes,
        'capturedAt': DateTime.now().toUtc().toIso8601String(),
        'sourceRoi': <String, Object?>{
          'left': result.sourceRoi.left,
          'top': result.sourceRoi.top,
          'right': result.sourceRoi.right,
          'bottom': result.sourceRoi.bottom,
        },
        'files': <String, String>{
          'original': originalName,
          'cropped': croppedName,
          'processed': processedName,
        },
        'original': quality['original'],
        'cropped': quality['cropped'],
      };
      final metadataFile = File(p.join(sampleDir.path, 'metadata.json'));
      await metadataFile.writeAsString(
        const JsonEncoder.withIndent('  ').convert(metadata),
        flush: true,
      );

      final record = EvidenceSampleRecord(
        id: sampleId,
        scenario: scenario.id,
        createdAt: DateTime.now(),
        originalFile: 'samples/$sampleId/$originalName',
        croppedFile: 'samples/$sampleId/$croppedName',
        processedFile: 'samples/$sampleId/$processedName',
        metadataFile: 'samples/$sampleId/metadata.json',
      );
      final updated = session.copyWith(
        samples: <EvidenceSampleRecord>[...session.samples, record],
      );
      await _writeSession(updated);
      return updated;
    } catch (_) {
      if (await sampleDir.exists()) {
        await sampleDir.delete(recursive: true);
      }
      rethrow;
    }
  }

  Future<Map<String, Object?>> _analyzeQualityOffUiIsolate({
    required String originalPath,
    required String croppedPath,
  }) {
    return Isolate.run(() async {
      const pipeline = CardCapturePipeline();
      final prepared = await pipeline.prepare(originalPath);
      final processor = CardScanProcessor();
      final originalQuality = await processor.analyzeQualityFile(
        prepared.normalized.path,
      );
      final croppedQuality = await processor.analyzeQualityFile(croppedPath);
      return <String, Object?>{
        'original': _qualityToJsonStatic(
          originalQuality,
          orientationNormalized: true,
        ),
        'cropped': _qualityToJsonStatic(
          croppedQuality,
          orientationNormalized: false,
        ),
      };
    });
  }

  Future<File> exportZip(EvidenceSession session) async {
    final root = await rootDirectory();
    final sessionDir = await _sessionDirectory(session.id);
    final exportDir = Directory(p.join(root.path, 'exports'));
    await exportDir.create(recursive: true);
    final zip = File(
      p.join(
        exportDir.path,
        'dxtr_card_scan_${_safeName(session.deviceLabel)}_${session.id}.zip',
      ),
    );

    final encoder = ZipFileEncoder();
    encoder.create(zip.path);
    await encoder.addDirectory(sessionDir, includeDirName: false);
    await encoder.close();
    return zip;
  }

  Future<void> shareZip(File zip) async {
    await SharePlus.instance.share(
      ShareParams(
        title: 'dxtr_card_scan calibration evidence',
        text: 'Physical calibration evidence ZIP',
        files: <XFile>[XFile(zip.path)],
      ),
    );
  }

  Future<Directory> _sessionDirectory(String id) async {
    final root = await rootDirectory();
    final dir = Directory(p.join(root.path, id));
    await dir.create(recursive: true);
    return dir;
  }

  Future<void> _writeSession(EvidenceSession session) async {
    final dir = await _sessionDirectory(session.id);
    final manifest = File(p.join(dir.path, 'session.json'));
    final temporaryManifest = File(p.join(dir.path, '.session.json.tmp'));
    await temporaryManifest.writeAsString(
      session.toPrettyJson(),
      flush: true,
    );
    await temporaryManifest.rename(manifest.path);

    await File(p.join(dir.path, 'README.txt')).writeAsString(
      _sessionReadme(session),
      flush: true,
    );
  }

  String _sessionReadme(EvidenceSession session) => '''
DXTR Card Scan physical calibration evidence

Protocol: v0.3 quality evidence
Device: ${session.deviceLabel}
Session: ${session.id}
Required matrix: ${evidenceScenarios.length} scenarios x ${EvidenceSession.samplesPerScenario} captures
Current samples: ${session.samples.length}/${session.requiredSampleCount}
Complete: ${session.isComplete}

Each sample folder contains:
- original image
- rectified crop
- processed image
- metadata.json with raw quality measurements and source ROI

Do not use this dataset as a pass/fail threshold by itself. It is raw calibration evidence.
''';

  String _extension(String path) {
    final extension = p.extension(path).toLowerCase();
    return extension.isEmpty ? '.jpg' : extension;
  }

  String _fileTimestamp(DateTime value) => value
      .toUtc()
      .toIso8601String()
      .replaceAll(':', '-')
      .replaceAll('.', '-');

  String _safeName(String value) => value
      .trim()
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9_-]+'), '_')
      .replaceAll(RegExp('_+'), '_');
}

Map<String, Object?> _qualityToJsonStatic(
  CardScanQualityAnalysis quality, {
  required bool orientationNormalized,
}) =>
    <String, Object?>{
      'orientationNormalized': orientationNormalized,
      'blur': <String, double>{
        'score': quality.blur.score,
        'laplacianVariance': quality.blur.laplacianVariance,
      },
      'exposure': <String, double>{
        'score': quality.exposure.score,
        'meanLuma': quality.exposure.meanLuma,
        'darkFraction': quality.exposure.darkFraction,
        'brightFraction': quality.exposure.brightFraction,
      },
      'glare': <String, double>{
        'score': quality.glare.score,
        'specularFraction': quality.glare.specularFraction,
        'peakTileFraction': quality.glare.peakTileFraction,
      },
      'cardCoverage': quality.cardCoverage,
      'detectionConfidence': quality.detectionConfidence,
    };
