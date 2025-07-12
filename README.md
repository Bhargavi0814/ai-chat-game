# AI Chat Game

A real-time, AI-powered multiplayer mobile chat game built with Flutter and Node.js. Players can join or create lobbies and chat with each other or Claude-powered AI bots in a lightweight, extensible gaming environment.

---

## 🧠 Features

- 🔌 **Real-time communication** via WebSockets (Socket.IO)
- 🏠 **Lobby system** with live participant count and join/create functionality
- 🤖 **Claude AI integration** for in-lobby conversational bots
- 🔁 **Bot response streaming** (simulated stream with Claude)
- 🎮 **Trivia game loop** injected every 60 seconds
- 📱 **Flutter-based Android client** with a clean, responsive UI
- 🔐 Secure `.env` management with OpenRouter Claude API

---

## 📐 Architecture

```mermaid
graph TD
  A[Flutter Client (Android)] -- WebSocket --> B[Node.js Server]
  B -- HTTP POST --> C[Claude via OpenRouter API]
  B --> D[Lobby Management & Trivia Engine]
```

---

## 🛠 Tech Stack

| Layer        | Technology                      |
|--------------|----------------------------------|
| Frontend     | Flutter (Dart)                   |
| Backend      | Node.js, Express, Socket.IO      |
| AI API       | Claude (via OpenRouter)          |
| Deployment   | Android APK (Flutter build)      |

---

## 🤖 Prompt Strategy

- System prompt: `You are a friendly AI chatbot helping players in a multiplayer game lobby...`
- Human messages vs. Bot replies categorized into `user` and `assistant` roles
- Last 6 messages are included for context
- Streaming Claude API responses with `delta.content` and emitting `botTyping`

---

## ⚙️ Environment Variables

In `/server/.env`:

```
OPENROUTER_API_KEY=your_openrouter_api_key_here
```

> ✅ Note: `.env` is excluded from Git via `.gitignore`

---

## 🧪 How to Run

### 🔧 Backend

```bash
cd server
npm install
node index.js
```

Ensure your `.env` has the correct Claude API key.

---

### 📲 Flutter App

```bash
cd client
flutter pub get
flutter run
```

To build a release APK:

```bash
flutter build apk --release
```

---

## 🚧 Known Limitations

- No user authentication (anonymous user IDs)
- No error handling on duplicate lobby names
- AI typing stream is simulated; not actual Claude SSE
- AI latency may vary based on Claude API response times

---

## 🧩 Future Enhancements

- User avatars and authentication
- Multiple bot types and personalities
- Scorekeeping or voting in trivia mode
- Web or iOS client support
- Claude streaming using `fetchEventSource` or native SSE client

---

## 📁 Folder Structure

```
ai-chat-game/
├── client/           # Flutter frontend
│   └── lib/
│       └── main.dart
├── server/           # Node.js backend
│   ├── index.js
│   └── .env          # Ignored from Git
├── README.md
```

---

## 📄 License

MIT – free to use, modify, and share.
