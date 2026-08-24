import 'dart:io';

import 'package:dxtr_card_scan/dxtr_card_scan.dart';
import 'package:flutter/material.dart';

import 'evidence_models.dart';
import 'evidence_store.dart';

class EvidenceHomePage extends StatefulWidget {
  const EvidenceHomePage({super.key});

  @override
  State<EvidenceHomePage> createState() => _EvidenceHomePageState();
}

class _EvidenceHomePageState extends State<EvidenceHomePage> {
  final EvidenceStore _store = EvidenceStore();
  final TextEditingController _deviceController = TextEditingController();

  EvidenceSession? _session;
  List<EvidenceSession> _sessions = const <EvidenceSession>[];
  bool _loading = true;
  bool _busy = false;
  String? _rootPath;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final metadata = await _store.readDeviceMetadata();
      final root = await _store.rootDirectory();
      final sessions = await _store.loadSessions();
      if (!mounted) return;
      setState(() {
        _rootPath = root.path;
        _sessions = sessions;
        _session = sessions.isEmpty ? null : sessions.first;
        _deviceController.text = _session?.deviceLabel ??
            _store.suggestedDeviceLabel(metadata);
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = '$error';
        _loading = false;
      });
    }
  }

  Future<void> _newSession() async {
    final label = _deviceController.text.trim();
    if (label.isEmpty) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final session = await _store.createSession(deviceLabel: label);
      final sessions = await _store.loadSessions();
      if (!mounted) return;
      setState(() {
        _session = session;
        _sessions = sessions;
      });
    } catch (error) {
      if (mounted) setState(() => _error = '$error');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _capture(EvidenceScenario scenario) async {
    final session = _session;
    if (session == null) return;
    final updated = await Navigator.of(context).push<EvidenceSession>(
      MaterialPageRoute<EvidenceSession>(
        builder: (_) => _EvidenceCapturePage(
          store: _store,
          session: session,
          scenario: scenario,
        ),
      ),
    );
    if (updated == null || !mounted) return;
    final sessions = await _store.loadSessions();
    if (!mounted) return;
    setState(() {
      _session = updated;
      _sessions = sessions;
    });
  }

  Future<void> _export() async {
    final session = _session;
    if (session == null || !session.isComplete) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final zip = await _store.exportZip(session);
      if (!mounted) return;
      if (Platform.isIOS) {
        await _store.shareZip(zip);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('ZIP saved: ${zip.path}')),
        );
      }
    } catch (error) {
      if (mounted) setState(() => _error = '$error');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  void dispose() {
    _deviceController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final session = _session;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Physical Calibration Evidence'),
        actions: [
          if (_busy)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Center(
                child: SizedBox.square(
                  dimension: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'v0.3 evidence collector',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 6),
          const Text(
            'Collect raw physical-device evidence only. This app does not apply readiness or pass/fail thresholds.',
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _deviceController,
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              labelText: 'Device label',
              hintText: 'e.g. Samsung SM-A165F or iPhone 11',
            ),
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: _busy ? null : _newSession,
            icon: const Icon(Icons.add),
            label: const Text('Start new device session'),
          ),
          if (_sessions.isNotEmpty) ...[
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: session?.id,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                labelText: 'Saved sessions',
              ),
              items: _sessions
                  .map(
                    (item) => DropdownMenuItem<String>(
                      value: item.id,
                      child: Text('${item.deviceLabel} — ${item.id}'),
                    ),
                  )
                  .toList(growable: false),
              onChanged: (id) {
                final selected = _sessions.where((item) => item.id == id);
                if (selected.isEmpty) return;
                setState(() {
                  _session = selected.first;
                  _deviceController.text = selected.first.deviceLabel;
                });
              },
            ),
          ],
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(
              _error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ],
          if (session != null) ...[
            const SizedBox(height: 20),
            _SessionSummary(session: session),
            const SizedBox(height: 16),
            ...evidenceScenarios.map(
              (scenario) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _ScenarioCard(
                  scenario: scenario,
                  count: session.countFor(scenario.id),
                  onCapture: session.countFor(scenario.id) >=
                          EvidenceSession.samplesPerScenario
                      ? null
                      : () => _capture(scenario),
                ),
              ),
            ),
            const SizedBox(height: 8),
            FilledButton.icon(
              onPressed: session.isComplete && !_busy ? _export : null,
              icon: Icon(Platform.isIOS ? Icons.ios_share : Icons.archive),
              label: Text(
                Platform.isIOS ? 'Create & Share ZIP' : 'Create ZIP',
              ),
            ),
            const SizedBox(height: 12),
            if (_rootPath != null)
              SelectableText(
                Platform.isAndroid
                    ? 'Android Device Explorer path:\n$_rootPath'
                    : 'App evidence path:\n$_rootPath\n\nOn iPhone, use Create & Share ZIP, then choose Save to Files or AirDrop.',
              ),
          ],
        ],
      ),
    );
  }
}

class _SessionSummary extends StatelessWidget {
  const _SessionSummary({required this.session});

  final EvidenceSession session;

  @override
  Widget build(BuildContext context) {
    final progress = session.samples.length / session.requiredSampleCount;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(session.deviceLabel, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            LinearProgressIndicator(value: progress.clamp(0, 1)),
            const SizedBox(height: 8),
            Text(
              '${session.samples.length}/${session.requiredSampleCount} samples — ${session.isComplete ? 'complete' : 'in progress'}',
            ),
          ],
        ),
      ),
    );
  }
}

class _ScenarioCard extends StatelessWidget {
  const _ScenarioCard({
    required this.scenario,
    required this.count,
    required this.onCapture,
  });

  final EvidenceScenario scenario;
  final int count;
  final VoidCallback? onCapture;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              child: Text('$count/${EvidenceSession.samplesPerScenario}'),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    scenario.title,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 4),
                  Text(scenario.guide),
                  const SizedBox(height: 10),
                  FilledButton.tonalIcon(
                    onPressed: onCapture,
                    icon: Icon(onCapture == null ? Icons.check : Icons.camera_alt),
                    label: Text(onCapture == null ? 'Completed' : 'Capture sample'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EvidenceCapturePage extends StatefulWidget {
  const _EvidenceCapturePage({
    required this.store,
    required this.session,
    required this.scenario,
  });

  final EvidenceStore store;
  final EvidenceSession session;
  final EvidenceScenario scenario;

  @override
  State<_EvidenceCapturePage> createState() => _EvidenceCapturePageState();
}

class _EvidenceCapturePageState extends State<_EvidenceCapturePage> {
  final TextEditingController _notesController = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _completed(CardCaptureResult result) async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      final updated = await widget.store.saveCapture(
        session: widget.session,
        scenario: widget.scenario,
        result: result,
        notes: _notesController.text.trim(),
      );
      if (!mounted) return;
      Navigator.of(context).pop(updated);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.scenario.title)),
      body: Column(
        children: [
          Material(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    widget.scenario.guide,
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _notesController,
                    decoration: const InputDecoration(
                      isDense: true,
                      border: OutlineInputBorder(),
                      labelText: 'Optional notes',
                    ),
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            child: Stack(
              children: [
                Positioned.fill(
                  child: CardCaptureView(
                    confirmationMode: CaptureConfirmationMode.afterCrop,
                    onCompleted: _completed,
                    onClose: () => Navigator.of(context).maybePop(),
                  ),
                ),
                if (_saving)
                  const Positioned.fill(
                    child: ColoredBox(
                      color: Color(0x66000000),
                      child: Center(child: CircularProgressIndicator()),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
