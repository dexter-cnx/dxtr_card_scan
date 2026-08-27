import 'dart:io';

import 'package:dxtr_card_scan/dxtr_card_scan.dart' as api;
import 'package:dxtr_card_scan/dxtr_card_scan_advanced.dart' as advanced;
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('primary barrel keeps high-level construction available', () {
    const config = api.CardAutoCaptureConfig();
    final view = api.CardCaptureView(onCompleted: (_) async {});

    expect(config.enabled, isFalse);
    expect(view.autoCapture, config);
  });

  test('advanced barrel exposes orchestration contracts', () {
    final tracker = advanced.CardCaptureStabilityTracker();
    final coordinator = advanced.CardLiveCaptureCoordinator(
      stabilityTracker: tracker,
    );
    const analyzer = advanced.CardLiveFrameAnalyzer();
    final feedback = advanced.CardLiveFeedbackController();

    expect(coordinator.stableFrameCount, 0);
    expect(analyzer.jpegQuality, 80);
    expect(feedback.value, isNull);
    feedback.dispose();
  });

  test('root barrel does not re-export low-level orchestration files', () {
    final barrel = File('lib/dxtr_card_scan.dart').readAsStringSync();

    for (final path in <String>[
      'card_capture_pipeline.dart',
      'card_capture_stability_tracker.dart',
      'card_live_camera_session.dart',
      'card_live_capture_coordinator.dart',
      'card_live_feedback_controller.dart',
      'card_live_frame_analyzer.dart',
      'card_live_feedback_overlay_layer.dart',
    ]) {
      expect(barrel, isNot(contains(path)), reason: path);
    }

    expect(
      barrel,
      contains(
        "export 'src/capture/card_auto_capture_policy.dart' show CardAutoCaptureConfig;",
      ),
    );
  });
}
