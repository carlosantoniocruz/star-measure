import 'package:showdist/measure/units.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('metric', () {
    test('sub-10cm keeps a decimal', () => expect(formatLength(0.0342, UnitSystem.metric), '3.4 cm'));
    test('under a metre is whole cm', () => expect(formatLength(0.234, UnitSystem.metric), '23 cm'));
    test('a metre and over is metres', () => expect(formatLength(1.2345, UnitSystem.metric), '1.23 m'));
  });

  group('imperial', () {
    test('under a foot is inches', () => expect(formatLength(0.1016, UnitSystem.imperial), '4″'));
    test('over a foot is feet and inches, to the nearest half inch',
        () => expect(formatLength(1.0, UnitSystem.imperial), '3′ 3 1/2″'));
    test('exact feet', () => expect(formatLength(0.3048, UnitSystem.imperial), '1′ 0″'));
    test('rounds to the nearest half inch, not finer',
        () => expect(formatLength(1.409955, UnitSystem.imperial), '4′ 7 1/2″'));
  });
}
