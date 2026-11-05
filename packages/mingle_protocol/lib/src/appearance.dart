/// Body colours a player can pick (ARGB).
abstract final class Palette {
  static const colors = [
    0xFFFF7043,
    0xFF42A5F5,
    0xFFAB47BC,
    0xFFFFCA28,
    0xFF26A69A,
    0xFFEC407A,
    0xFF8D6E63,
    0xFF5C6BC0,
  ];

  static bool isValid(int color) => colors.contains(color);
}

/// Headwear a player can pick.
enum Hat {
  none,
  cap,
  beanie,
  crown,
  bow,
  flower;

  static Hat? tryParse(String name) {
    for (final h in values) {
      if (h.name == name) return h;
    }
    return null;
  }
}
