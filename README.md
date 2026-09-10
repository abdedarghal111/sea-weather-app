# Sea Weather

<p align="center">
    <img src="./.github/images/logo.png" alt="App icon" width="200">
</p>

<p align="center">
    <a href="#sobre-este-proyecto">Sobre este proyecto</a> ·
    <a href="#pruébala">Pruébala</a> ·
    <a href="#desarrollo">Desarrollo</a> ·
    <a href="#capturas">Capturas</a> ·
    <a href="#menciones-honorables">Menciones honorables</a>
</p>

## Sobre este proyecto

Consulta el tiempo y el estado del mar en tus localidades favoritas: una cala, una playa, un lago, un embalse o tu propia ciudad. Cuenta con 5 indicadores sencillos para informar sobre si el agua está clara u opaca, si la playa está tranquila o removida, si es buena para surfear, si hay suficiente sol y si va a llover.

Esta aplicación es un proyecto personal. A diferencia de otras apps de tiempo, su objetivo es simplificar la decisión de "¿hoy es buen día para ir a la playa?" reduciéndola a 5 indicadores claros, en vez de mostrar montones de datos meteorológicos y marinos que hay que interpretar uno mismo.

## Pruébala

Descarga la [última release](https://github.com/abdedarghal111/sea-weather-app/releases/latest):

- Android — `android_vX.Y.Z.apk` y `android_vX.Y.Z.aab`
- iOS — `ios_unsigned_vX.Y.Z.ipa`
- Windows — `windows_executable_vX.Y.Z.zip`
- macOS — `macos_executable_vX.Y.Z.zip`
- Linux — `linux_executable_vX.Y.Z.tar.gz`
- Web — `web_build_vX.Y.Z.zip`

Los builds de Android e iOS no están firmados (proyecto personal, sin certificados), y el APK/AAB solo se compila para arm64.

## Desarrollo

Las carpetas nativas (`android/`, `windows/`, `web/`, ...) no están en el repo — se generan localmente:

```
flutter pub get
flutter create --platforms=android,ios,windows,macos,linux,web --org es.abderra .
dart run flutter_launcher_icons
```

Esto solo hace falta la primera vez (o si borras esas carpetas de nuevo). El último comando regenera el icono de la app (`.github/images/logo.png`) en las carpetas nativas, ya que `flutter create` las deja con el icono por defecto de Flutter.

Ejecutar (`flutter devices` lista los ids de los móviles conectados):

```
flutter run -d windows
flutter run -d macos
flutter run -d linux
flutter run -d chrome
flutter run -d <id-del-dispositivo-android>
flutter run -d <id-del-dispositivo-ios>
```

Tests:

```
flutter test
```

Compilar:

```
flutter build apk
flutter build appbundle
flutter build ipa
flutter build windows
flutter build macos
flutter build linux
flutter build web
```

## Capturas

<p align="center">
    <img src="./.github/images/showcase1.png" alt="Lista de localidades vacía" width="200">
    <img src="./.github/images/showcase2.png" alt="Búsqueda de una población por nombre" width="200">
    <img src="./.github/images/showcase3.png" alt="Elegir el punto de una cala, playa o embalse en el mapa" width="200">
    <img src="./.github/images/showcase4.png" alt="Lista de localidades guardadas con sus indicadores" width="200">
    <img src="./.github/images/showcase5.png" alt="Detalle de una localidad: indicadores de ahora" width="200">
    <img src="./.github/images/showcase6.png" alt="Detalle de una localidad: previsión por horas" width="200">
    <img src="./.github/images/showcase7.png" alt="Detalle de una localidad: indicadores de los próximos días" width="200">
    <img src="./.github/images/showcase8.png" alt="Detalle de una localidad: datos meteorológicos de los próximos días" width="200">
    <img src="./.github/images/showcase9.png" alt="Detalle de una localidad: todos los datos de ahora" width="200">
</p>

Las capturas son de la v1.0.0: algunos rótulos y pantallas han cambiado desde entonces.

## Menciones honorables

- [Open-Meteo](https://open-meteo.com/) — previsión meteorológica, marina y geocoding, gratis y sin necesidad de API key.
- [OpenStreetMap](https://www.openstreetmap.org/) — datos y tiles del mapa.
