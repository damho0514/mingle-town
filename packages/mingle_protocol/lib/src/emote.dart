/// Quick reactions a player can show above their character.
enum Emote {
  wave,
  heart,
  laugh,
  wow,
  sad,
  party;

  static Emote? tryParse(String name) {
    for (final e in values) {
      if (e.name == name) return e;
    }
    return null;
  }
}
