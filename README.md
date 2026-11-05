# Mingle Town

캐릭터로 동시 접속자끼리 함께 노는 공간 게임. Flutter + [Flame](https://flame-engine.org) (Android / iOS) 클라이언트와 Dart WebSocket 서버로 구성돼 있어요.

## 구조

| 경로 | 설명 |
|---|---|
| `lib/` | Flutter 앱 (로비 → 게임 화면) |
| `lib/game/` | Flame 월드: 바닥(`ground.dart`), 캐릭터·말풍선(`character.dart`), 게임 루트(`mingle_town_game.dart`) |
| `lib/net/` | 서버 연결 (`GameConnection`) |
| `server/` | 실시간 방 서버 (shelf + WebSocket) |
| `packages/mingle_protocol/` | 앱·서버가 공유하는 메시지 정의와 제한값 |

## 로컬 실행

```bash
# 1) 서버
cd server && dart run bin/server.dart      # ws://0.0.0.0:8080, PORT 환경변수로 변경

# 2) 앱 (다른 터미널, 기기/시뮬레이터 연결 후)
flutter run
```

기본 서버 주소는 Android 에뮬레이터 `ws://10.0.2.2:8080`, iOS 시뮬레이터 `ws://localhost:8080`이에요.
실기기는 로비 화면에서 PC의 LAN IP(예: `ws://192.168.0.10:8080`)를 입력하거나
`flutter run --dart-define=SERVER_URL=ws://...`로 지정하세요.

여러 명 테스트: 기기/시뮬레이터 여러 대에서 같은 서버로 접속하면 서로의 캐릭터가 보여요.

## 프로토콜

모든 메시지는 `t` 필드를 가진 JSON 객체예요 (`packages/mingle_protocol/lib/src/messages.dart`).

- 클라이언트 → 서버: `join(name)`, `move(x, y)`, `chat(text)`
- 서버 → 클라이언트: `welcome(selfId, players)`, `joined`, `left`, `moved`, `chat`, `error`

서버가 닉네임(16자)·채팅(100자) 길이와 월드 좌표(1600×1600)를 검증해요.

## 테스트

```bash
(cd packages/mingle_protocol && dart test)
(cd server && dart test)
flutter test
```
