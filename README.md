# Sea Wether

Consulta el tiempo y el estado del mar en tus playas y calas favoritas.

## Setup

Las carpetas nativas (`android/`, `windows/`, `web/`, ...) no están en el repo — se generan localmente:

```
flutter pub get
flutter create --platforms=android,windows,web --org com.example .
```

Esto solo hace falta la primera vez (o si borras esas carpetas de nuevo).

## Ejecutar

```
flutter run -d windows
flutter run -d chrome
flutter run -d <id-del-dispositivo-android>
```

## Build

```
flutter build windows
flutter build web
flutter build apk
```
