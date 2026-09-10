// Versión semántica de la app, comparable numéricamente.

/// Versión semántica (`1.2.3`) comparable con otra. Comparar como texto no
/// vale: `"1.10.0"` es menor que `"1.9.0"` alfabéticamente.
class AppVersion implements Comparable<AppVersion> {
  /// Números de la versión, de más significativo a menos. Puede haber menos
  /// de tres si el origen no los trae (`v2` es `[2]`).
  final List<int> parts;

  const AppVersion(this.parts);

  /// Acepta el tag de GitHub (`v1.2.3`) y `pubspec.yaml` (`1.2.3+4`). El
  /// build (`+4`) y el sufijo de pre-release (`-beta`) se ignoran. Devuelve
  /// `null` si no hay ningún número que comparar.
  static AppVersion? tryParse(String raw) {
    var text = raw.trim();
    if (text.startsWith('v') || text.startsWith('V')) text = text.substring(1);
    text = text.split('+').first.split('-').first;

    final parts = <int>[];
    for (final piece in text.split('.')) {
      final value = int.tryParse(piece.trim());
      if (value == null || value < 0) return null;
      parts.add(value);
    }
    return parts.isEmpty ? null : AppVersion(parts);
  }

  /// Compara parte a parte tratando las que faltan como cero, para que `1.2`
  /// y `1.2.0` sean la misma versión.
  @override
  int compareTo(AppVersion other) {
    final length = parts.length > other.parts.length ? parts.length : other.parts.length;
    for (var i = 0; i < length; i++) {
      final mine = i < parts.length ? parts[i] : 0;
      final theirs = i < other.parts.length ? other.parts[i] : 0;
      if (mine != theirs) return mine.compareTo(theirs);
    }
    return 0;
  }

  bool operator >(AppVersion other) => compareTo(other) > 0;

  @override
  bool operator ==(Object other) => other is AppVersion && compareTo(other) == 0;

  @override
  int get hashCode => Object.hashAll(parts);

  @override
  String toString() => parts.join('.');
}
