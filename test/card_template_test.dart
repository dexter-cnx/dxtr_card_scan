import 'package:dxtr_card_scan/dxtr_card_scan.dart';
import 'package:flutter_test/flutter_test.dart';

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

  test('template rejects duplicate region names after trimming', () {
    expect(
      () => CardTemplate(
        id: 'card',
        regions: const [
          nameRegion,
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

  test('template rejects zero-area regions', () {
    expect(
      () => CardTemplate(
        id: 'card',
        regions: const [
          CardTemplateRegion(
            name: 'empty',
            rect: NormalizedRect(
              left: 0.2,
              top: 0.2,
              right: 0.2,
              bottom: 0.4,
            ),
          ),
        ],
      ),
      throwsArgumentError,
    );
  });
}
