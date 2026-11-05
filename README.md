# Mingle Town

캐릭터로 동시 접속자끼리 함께 노는 공간 게임. Flutter + [Flame](https://flame-engine.org) 기반 (Android / iOS).

## 개발

```bash
flutter pub get
flutter run          # 연결된 기기/에뮬레이터에서 실행
flutter test
```

## 구조

- `lib/main.dart` — 앱 진입점
- `lib/game/` — Flame 게임 (월드, 캐릭터)
