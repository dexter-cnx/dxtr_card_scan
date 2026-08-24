import 'dart:convert';

const evidenceScenarios = <EvidenceScenario>[
  EvidenceScenario(
    id: 'good',
    title: 'Good capture',
    guide: 'Steady capture, normal indoor light, card fills the guide.',
  ),
  EvidenceScenario(
    id: 'blur',
    title: 'Blur',
    guide: 'Create deliberate hand motion or defocus while capturing.',
  ),
  EvidenceScenario(
    id: 'dark',
    title: 'Dark',
    guide: 'Capture in a dim or visibly underexposed environment.',
  ),
  EvidenceScenario(
    id: 'bright',
    title: 'Bright',
    guide: 'Use strong light so part of the card approaches clipped highlights.',
  ),
  EvidenceScenario(
    id: 'small-card',
    title: 'Small card',
    guide: 'Move farther away so the card occupies clearly less of the frame.',
  ),
  EvidenceScenario(
    id: 'perspective',
    title: 'Perspective',
    guide: 'Tilt the card to a noticeable but still usable perspective angle.',
  ),
  EvidenceScenario(
    id: 'busy-background',
    title: 'Busy background',
    guide: 'Place the card over a high-contrast or card-like background.',
  ),
];

class EvidenceScenario {
  const EvidenceScenario({
    required this.id,
    required this.title,
    required this.guide,
  });

  final String id;
  final String title;
  final String guide;
}

class EvidenceSampleRecord {
  const EvidenceSampleRecord({
    required this.id,
    required this.scenario,
    required this.createdAt,
    required this.originalFile,
    required this.croppedFile,
    required this.processedFile,
    required this.metadataFile,
  });

  final String id;
  final String scenario;
  final DateTime createdAt;
  final String originalFile;
  final String croppedFile;
  final String processedFile;
  final String metadataFile;

  Map<String, Object?> toJson() => <String, Object?>{
        'id': id,
        'scenario': scenario,
        'createdAt': createdAt.toUtc().toIso8601String(),
        'originalFile': originalFile,
        'croppedFile': croppedFile,
        'processedFile': processedFile,
        'metadataFile': metadataFile,
      };

  factory EvidenceSampleRecord.fromJson(Map<String, Object?> json) {
    return EvidenceSampleRecord(
      id: json['id']! as String,
      scenario: json['scenario']! as String,
      createdAt: DateTime.parse(json['createdAt']! as String),
      originalFile: json['originalFile']! as String,
      croppedFile: json['croppedFile']! as String,
      processedFile: json['processedFile']! as String,
      metadataFile: json['metadataFile']! as String,
    );
  }
}

class EvidenceSession {
  const EvidenceSession({
    required this.id,
    required this.deviceLabel,
    required this.deviceMetadata,
    required this.createdAt,
    required this.samples,
  });

  final String id;
  final String deviceLabel;
  final Map<String, Object?> deviceMetadata;
  final DateTime createdAt;
  final List<EvidenceSampleRecord> samples;

  static const samplesPerScenario = 3;

  int countFor(String scenario) =>
      samples.where((sample) => sample.scenario == scenario).length;

  int get requiredSampleCount => evidenceScenarios.length * samplesPerScenario;

  bool get isComplete => evidenceScenarios.every(
        (scenario) => countFor(scenario.id) >= samplesPerScenario,
      );

  EvidenceSession copyWith({
    String? deviceLabel,
    Map<String, Object?>? deviceMetadata,
    List<EvidenceSampleRecord>? samples,
  }) {
    return EvidenceSession(
      id: id,
      deviceLabel: deviceLabel ?? this.deviceLabel,
      deviceMetadata: deviceMetadata ?? this.deviceMetadata,
      createdAt: createdAt,
      samples: samples ?? this.samples,
    );
  }

  Map<String, Object?> toJson() => <String, Object?>{
        'schemaVersion': 1,
        'protocol': 'v0.3-quality-evidence',
        'id': id,
        'deviceLabel': deviceLabel,
        'deviceMetadata': deviceMetadata,
        'createdAt': createdAt.toUtc().toIso8601String(),
        'samplesPerScenario': samplesPerScenario,
        'samples': samples.map((sample) => sample.toJson()).toList(),
      };

  String toPrettyJson() => const JsonEncoder.withIndent('  ').convert(toJson());

  factory EvidenceSession.fromJson(Map<String, Object?> json) {
    return EvidenceSession(
      id: json['id']! as String,
      deviceLabel: json['deviceLabel']! as String,
      deviceMetadata: Map<String, Object?>.from(
        json['deviceMetadata']! as Map,
      ),
      createdAt: DateTime.parse(json['createdAt']! as String),
      samples: (json['samples']! as List)
          .map(
            (sample) => EvidenceSampleRecord.fromJson(
              Map<String, Object?>.from(sample as Map),
            ),
          )
          .toList(growable: false),
    );
  }
}
