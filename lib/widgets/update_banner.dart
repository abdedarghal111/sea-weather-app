import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/update_check.dart';

/// Aviso de versión nueva sobre la lista de calas, con enlace directo a la
/// release para descargarla. Mientras se comprueba, y cuando ya se está en la
/// última versión, no ocupa nada en pantalla.
class UpdateBanner extends StatefulWidget {
  const UpdateBanner({super.key});

  @override
  State<UpdateBanner> createState() => _UpdateBannerState();
}

class _UpdateBannerState extends State<UpdateBanner> {
  final _checker = UpdateChecker();

  /// Creado una sola vez: dentro de `build` se relanzaría en cada rebuild de
  /// la pantalla.
  late Future<UpdateCheck> _check = _checker.check();

  void _retry() {
    // El cuerpo va entre llaves a propósito: con `=>` la asignación devuelve
    // el propio Future y `setState` lo rechaza creyendo que el callback es
    // asíncrono.
    setState(() {
      _check = _checker.check(forceRefresh: true);
    });
  }

  /// Abre la release en el navegador. Si no se puede (sin navegador, o el
  /// plugin nativo no responde en esta plataforma), se copia la dirección al
  /// portapapeles: dejar al usuario sin forma de llegar a la descarga sería
  /// peor que el propio fallo.
  Future<void> _openRelease(String url) async {
    final messenger = ScaffoldMessenger.of(context);
    var opened = false;
    try {
      opened = await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    } catch (_) {
      // `launchUrl` lanza PlatformException si el plugin no está disponible,
      // no devuelve false: sin este catch, la excepción sube sin recoger.
    }
    if (opened) return;

    await Clipboard.setData(ClipboardData(text: url));
    messenger.showSnackBar(
      const SnackBar(
        content: Text('No se pudo abrir el navegador. Enlace copiado al portapapeles.'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<UpdateCheck>(
      future: _check,
      builder: (context, snapshot) {
        // Sin datos todavía no se pinta nada: un hueco que aparece y
        // desaparece empujaría la lista justo mientras se lee.
        final result = snapshot.data;
        return switch (result) {
          UpdateAvailable(:final version, :final releaseUrl) =>
            _available(context, version.toString(), releaseUrl),
          UpdateCheckFailed() => _failed(context),
          _ => const SizedBox.shrink(),
        };
      },
    );
  }

  Widget _available(BuildContext context, String version, String releaseUrl) {
    final colors = Theme.of(context).colorScheme;
    return Card(
      color: colors.primaryContainer,
      margin: const EdgeInsets.fromLTRB(12, 12, 12, 0),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            FaIcon(FontAwesomeIcons.circleArrowDown, color: colors.onPrimaryContainer),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Hay una versión nueva disponible: $version',
                style: TextStyle(color: colors.onPrimaryContainer),
              ),
            ),
            const SizedBox(width: 8),
            FilledButton(
              onPressed: () => _openRelease(releaseUrl),
              child: const Text('Descargar'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _failed(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
      child: Row(
        children: [
          FaIcon(FontAwesomeIcons.circleInfo, size: 14, color: colors.outline),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'No se pudo comprobar si hay actualizaciones.',
              style: TextStyle(fontSize: 12, color: colors.outline),
            ),
          ),
          TextButton(onPressed: _retry, child: const Text('Reintentar')),
        ],
      ),
    );
  }
}
