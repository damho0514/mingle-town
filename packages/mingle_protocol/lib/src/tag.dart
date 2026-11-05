/// Rules for the tag (술래잡기) mini-game.
abstract final class TagRules {
  static const Duration roundLength = Duration(seconds: 60);
  static const int minPlayers = 2;

  /// The tagger must get this close (feet to feet) to tag someone.
  static const double reach = 36;

  /// After a tag nobody can be tagged for this long (no instant tag-backs).
  static const Duration cooldown = Duration(milliseconds: 1500);
}

enum TagPhase { started, tagged, ended }
