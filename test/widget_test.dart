// Prueba de interfaz de la pantalla inicial sin localidades guardadas.

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:sea_weather_app/main.dart';

void main() {
  testWidgets('Empty locations list shows CTA to add first location', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});

    await tester.pumpWidget(const SeaWeatherApp());
    await tester.pumpAndSettle();

    expect(find.text('Todavía no tienes ninguna localidad guardada'), findsOneWidget);
    expect(find.text('Añadir tu primera localidad'), findsOneWidget);
  });
}
