# Mingle Town

캐릭터로 동시 접속자끼리 함께 노는 공간 게임. Flutter + [Flame](https://flame-engine.org) (Android / iOS / Web) 클라이언트와 Dart WebSocket 서버로 구성돼 있어요.

**지금 되는 것**: 닉네임으로 입장 → 광장·분수·연못·숲이 있는 1600×1600 마을에서 탭으로 이동(걷기 애니메이션), 말풍선 채팅, 이모트(👋❤️😂😮😢🎉), 접속자 수 표시.

## 구조

| 경로 | 설명 |
|---|---|
| `lib/` | Flutter 앱 (로비 → 게임 화면) |
| `lib/game/` | Flame 월드: 지형(`ground.dart`, `world_layout.dart`), 나무(`tree.dart`), 캐릭터·말풍선·이모트(`character.dart`), 게임 루트·카메라(`mingle_town_game.dart`) |
| `lib/net/` | 서버 연결 (`GameConnection`) |
| `server/` | 실시간 방 서버 (shelf + WebSocket), `tool/bot.dart` 테스트 봇, `Dockerfile` |
| `packages/mingle_protocol/` | 앱·서버가 공유하는 메시지 정의와 제한값 |

## 로컬 실행

```bash
# 1) 서버
cd server && dart run bin/server.dart      # ws://0.0.0.0:8080, PORT 환경변수로 변경

# 2-a) Android 에뮬레이터
emulator -avd mingle_town -gpu host &      # (Android SDK emulator 경로) -gpu host 필수: 소프트웨어 렌더링은 매우 느림
flutter run -d emulator-5554

# 2-b) 웹 (Chrome)
flutter run -d chrome
# 또는 빌드 후 정적 서빙: flutter build web && (cd build/web && python3 -m http.server 5173)

# 3) 혼자 테스트할 때: 돌아다니며 말하고 이모트하는 봇 N명
cd server && dart run tool/bot.dart ws://localhost:8080 2
```

iOS 시뮬레이터는 Xcode(App Store) 설치 후 `flutter run -d ios`로 실행해요.

기본 서버 주소는 Android 에뮬레이터 `ws://10.0.2.2:8080`, iOS 시뮬레이터 `ws://localhost:8080`이에요.
실기기는 로비 화면에서 PC의 LAN IP(예: `ws://192.168.0.10:8080`)를 입력하거나
`flutter run --dart-define=SERVER_URL=ws://...`로 지정하세요.

여러 명 테스트: 기기/시뮬레이터 여러 대에서 같은 서버로 접속하면 서로의 캐릭터가 보여요.

## 서버 배포 (Fly.io)

`server/Dockerfile`과 `fly.toml`이 준비돼 있어요. 방 상태가 메모리에 있으므로 **머신은 1대**로 운영해요.

```bash
fly auth login
fly launch --no-deploy --copy-config --name <고유한-앱-이름>
fly deploy --ha=false
```

앱은 `--dart-define=SERVER_URL=wss://<앱-이름>.fly.dev`로 빌드하거나 로비에서 주소를 입력해요.

## 프로토콜

모든 메시지는 `t` 필드를 가진 JSON 객체예요 (`packages/mingle_protocol/lib/src/messages.dart`).

- 클라이언트 → 서버: `join(name)`, `move(x, y)`, `chat(text)`, `emote(e)`
- 서버 → 클라이언트: `welcome(selfId, players)`, `joined`, `left`, `moved`, `chat`, `emoted`, `error`

서버가 닉네임(16자)·채팅(100자) 길이와 월드 좌표(1600×1600)를 검증하고, 채팅+이모트는 5초에 5회로 제한해요.

## 테스트

```bash
(cd packages/mingle_protocol && dart test)
(cd server && dart test)
flutter test
```
