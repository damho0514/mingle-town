/// World and input limits enforced by the server and respected by clients.
abstract final class Limits {
  static const double worldWidth = 1600;
  static const double worldHeight = 1600;
  static const int maxNameLength = 16;
  static const int maxChatLength = 100;

  /// Walking speed in world units per second.
  static const double walkSpeed = 220;

  /// Collision radius of a character's feet.
  static const double playerRadius = 10;
}

/// Rate limit for social actions (chat + emote) per player.
abstract final class SocialRateLimit {
  static const int burst = 5;
  static const Duration window = Duration(seconds: 5);
}

/// Position updates a client may send per second; extra ones are dropped.
abstract final class MoveRateLimit {
  static const int perSecond = 20;

  /// How often clients stream their position while moving.
  static const Duration sendInterval = Duration(milliseconds: 100);
}
