// Pruebas del parseo y la comparación de versiones de la app.

import 'package:flutter_test/flutter_test.dart';
import 'package:sea_weather_app/models/app_version.dart';

void main() {
  group('AppVersion.tryParse', () {
    test('acepta el tag de GitHub con la v delante', () {
      expect(AppVersion.tryParse('v1.2.3').toString(), '1.2.3');
    });

    test('ignora el build de pubspec y el sufijo de pre-release', () {
      expect(AppVersion.tryParse('1.2.3+45').toString(), '1.2.3');
      expect(AppVersion.tryParse('v2.0.0-beta').toString(), '2.0.0');
    });

    test('rechaza lo que no es una versión', () {
      expect(AppVersion.tryParse('latest'), isNull);
      expect(AppVersion.tryParse('1.x.3'), isNull);
      expect(AppVersion.tryParse(''), isNull);
    });
  });

  group('comparación', () {
    test('compara por número, no alfabéticamente', () {
      // El caso que rompe un `compareTo` de String: "1.10.0" < "1.9.0".
      expect(AppVersion.tryParse('1.10.0')! > AppVersion.tryParse('1.9.0')!, isTrue);
    });

    test('el mayor peso manda sobre el resto', () {
      expect(AppVersion.tryParse('2.0.0')! > AppVersion.tryParse('1.99.99')!, isTrue);
    });

    test('los huecos que faltan valen cero', () {
      expect(AppVersion.tryParse('1.2'), AppVersion.tryParse('1.2.0'));
      expect(AppVersion.tryParse('1.2.1')! > AppVersion.tryParse('1.2')!, isTrue);
    });

    test('la misma versión no es una actualización', () {
      expect(AppVersion.tryParse('v1.0.0')! > AppVersion.tryParse('1.0.0')!, isFalse);
    });
  });
}
