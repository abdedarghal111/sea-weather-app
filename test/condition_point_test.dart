import 'package:flutter_test/flutter_test.dart';
import 'package:sea_wether_app/models/trailing_window.dart';

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

  group('trailingMax', () {
    test('finds the max within the window', () {
      expect(trailingMax([1, 5, 2, 8, 3], 4, 3), 8); // max(2,8,3)
    });

    test('clamps to available history at the start of the array', () {
      expect(trailingMax([4, 9], 1, 10), 9);
    });

    test('a single-entry window returns that entry', () {
      expect(trailingMax([1, 5, 2], 0, 1), 1);
    });
  });
}
