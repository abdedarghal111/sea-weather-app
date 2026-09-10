import 'package:flutter_test/flutter_test.dart';
import 'package:sea_weather_app/models/trailing_window.dart';

void main() {
  group('trailingSum', () {
    test('sums the whole window when there is enough history', () {
      expect(trailingSum([1, 2, 3, 4, 5], 4, 3), 12); // 3+4+5
    });

    test('clamps to available history at the start of the array', () {
      expect(trailingSum([1, 2, 3], 1, 5), 3); // 1+2, only 2 entries exist
    });

    test('a single-entry window returns that entry', () {
      expect(trailingSum([10, 20, 30], 1, 1), 20);
    });
  });

  group('trailingAverage', () {
    test('averages the whole window when there is enough history', () {
      expect(trailingAverage([1, 2, 3, 4, 5], 4, 3), closeTo(4, 0.0001)); // (3+4+5)/3
    });

    test('clamps to available history at the start of the array', () {
      expect(trailingAverage([10, 20, 30], 0, 5), 10); // only index 0 exists
    });
  });

  group('trailingRms', () {
    test('a flat sea returns that same height', () {
      expect(trailingRms([1, 1, 1], 2, 3), closeTo(1, 0.0001));
    });

    test('weights the big hours more than a plain average would', () {
      // Media normal de [0, 0, 2, 0] = 0.5; en energía (altura al cuadrado)
      // esa hora de 2 m pesa mucho más y la media cuadrática sube a 1.
      expect(trailingRms([0, 0, 2, 0], 3, 4), closeTo(1, 0.0001));
    });

    test('a single peak hour does not drag the whole window up like a max would', () {
      final rms = trailingRms([0, 0, 0, 0, 0, 0, 0, 2], 7, 8)!;
      expect(rms, lessThan(1));
      expect(rms, closeTo(0.7071, 0.0001)); // sqrt(4/8)
    });

    test('skips the gaps inside the window', () {
      expect(trailingRms([2, null, 2], 2, 3), closeTo(2, 0.0001));
    });

    test('returns null when the anchor entry itself has no data', () {
      expect(trailingRms([1, 2, null], 2, 3), isNull);
    });

    test('returns null for a missing array or an out-of-range index', () {
      expect(trailingRms(null, 0, 48), isNull);
      expect(trailingRms([1, 2], 5, 48), isNull);
    });

    test('clamps to available history at the start of the array', () {
      expect(trailingRms([3, 4], 1, 10), closeTo(3.5355, 0.0001)); // sqrt((9+16)/2)
    });
  });
}
