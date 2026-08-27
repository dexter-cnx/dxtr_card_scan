import 'package:dxtr_card_scan/dxtr_card_scan.dart';
import 'package:flutter_test/flutter_test.dart';

class _RuntimeRect extends NormalizedRect {
  _RuntimeRect({
    required this.runtimeLeft,
    required this.runtimeTop,
    required this.runtimeRight,
    required this.runtimeBottom,
  }) : super(left: 0, top: 0, right: 1, bottom: 1);

  final double runtimeLeft;
  final double runtimeTop;
  final double runtimeRight;
  final double runtimeBottom;

  @override
  double get left => runtimeLeft;

  @override
  double get top => runtimeTop;

  @override
  double get right => runtimeRight;

  @override
  double get bottom => runtimeBottom;
}

void main() {
  const nameRegion = CardTemplateRegion(
    name: 'name',
    rect: NormalizedRect(
      left: 0.1,
      top: 0.2,
      right: 0.8,
      bottom: 0.35,
    ),
  );

  test('template preserves region order and supports lookup', () {
    const idRegion = CardTemplateRegion(
      name: 'idNumber',
      rect: NormalizedRect(
        left: 0.1,
        top: 0.4,
        right: 0.7,
        bottom: 0.5,
      ),
    );
    final template = CardTemplate(
      id: 'thai-id-front',
      regions: const [nameRegion, idRegion],
    );

    expect(template.regions, const [nameRegion, idRegion]);
    expect(template.region('name'), same(nameRegion));
    expect(template.region('missing'), isNull);
  });

  test('template regions are immutable', () {
    final regions = <CardTemplateRegion>[nameRegion];
    final template = CardTemplate(id: 'card', regions: regions);
    regions.clear();

    expect(template.regions, hasLength(1));
    expect(() => template.regions.add(nameRegion), throwsUnsupportedError);
  });

  test('template rejects empty ids', () {
    expect(
      () => CardTemplate(id: '  ', regions: const [nameRegion]),
      throwsArgumentError,
    );
  });

  test('template rejects duplicate region names', () {
    expect(
      () => CardTemplate(
        id: 'card',
        regions: const [nameRegion, nameRegion],
      ),
      throwsArgumentError,
    );
  });

  test('template rejects surrounding whitespace in region names', () {
    expect(
      () => CardTemplate(
        id: 'card',
        regions: const [
          CardTemplateRegion(
            name: ' name ',
            rect: NormalizedRect(
              left: 0.1,
              top: 0.5,
              right: 0.8,
              bottom: 0.6,
            ),
          ),
        ],
      ),
      throwsArgumentError,
    );
  });

  test('template rejects out-of-range regions at runtime', () {
    expect(
      () => CardTemplate(
        id: 'card',
        regions: [
          CardTemplateRegion(
            name: 'invalid',
            rect: _RuntimeRect(
              runtimeLeft: -0.1,
              runtimeTop: 0.2,
              runtimeRight: 0.8,
              runtimeBottom: 0.4,
            ),
          ),
        ],
      ),
      throwsArgumentError,
    );
  });

  test('template rejects non-finite regions at runtime', () {
    expect(
      () => CardTemplate(
        id: 'card',
        regions: [
          CardTemplateRegion(
            name: 'invalid',
            rect: _RuntimeRect(
              runtimeLeft: 0.1,
              runtimeTop: 0.2,
              runtimeRight: double.infinity,
              runtimeBottom: 0.4,
            ),
          ),
        ],
      ),
      throwsArgumentError,
    );
  });

  test('template rejects zero-area regions', () {
    expect(
      () => CardTemplate(
        id: 'card',
        regions: [
          CardTemplateRegion(
            name: 'empty',
            rect: _RuntimeRect(
              runtimeLeft: 0.2,
              runtimeTop: 0.2,
              runtimeRight: 0.2,
              runtimeBottom: 0.4,
            ),
          ),
        ],
      ),
      throwsArgumentError,
    );
  });
}
