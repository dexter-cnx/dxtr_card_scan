import 'package:dxtr_card_scan/dxtr_card_scan.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('quality metadata remains optional for source compatibility', () {
    const image = CardCaptureImage(path: 'capture.jpg', width: 100, height: 60);
    const result = CardCaptureResult(
      original: image,
      cropped: image,
      processed: image,
      sourceRoi: NormalizedRect(
        left: 0,
        top: 0,
        right: 1,
        bottom: 1,
      ),
    );

    expect(result.qualityMetadata, isNull);
  });
}
