require('dotenv').config();
const express = require('express');
const http = require('http');
const cors = require('cors');
const { Server } = require('socket.io');
const fetch = (...args) => import('node-fetch').then(({ default: fetch }) => fetch(...args));

const app = express();
app.use(cors());
const server = http.createServer(app);
const io = new Server(server, {
  cors: { origin: '*' },
});

const OPENROUTER_API_KEY = process.env.OPENROUTER_API_KEY;

let lobbies = {}; // { lobbyId: { users: [], bots: [], messages: [] } }

const triviaQuestions = [
  {
    question: "In a multiplayer game lobby, what's a common feature?",
    options: ["Create games", "Cook food", "Book tickets", "Print PDFs"],
    answer: "Create games"
  },
  {
    question: "What does 'ready up' mean in a game lobby?",
    options: ["Leave the lobby", "Prepare to start", "Pause the game", "Close the app"],
    answer: "Prepare to start"
  },
  {
    question: "Which of these is usually shown in a lobby?",
    options: ["Weather forecast", "Player list", "TV guide", "Invoice history"],
    answer: "Player list"
  },
  {
    question: "What happens when everyone is 'ready' in a game lobby?",
    options: ["Game starts", "Lobby closes", "Chat resets", "Scores are deleted"],
    answer: "Game starts"
  },
  {
    question: "Which platform is known for real-time multiplayer games?",
    options: ["Unity", "Zoom", "Excel", "Photoshop"],
    answer: "Unity"
  }
];

io.on('connection', (socket) => {
  console.log('Client connected:', socket.id);

  socket.emit('lobbyList', Object.keys(lobbies).map(id => ({
    id,
    participants: lobbies[id].users.length + lobbies[id].bots.length
  })));

  socket.on('createLobby', ({ lobbyId }) => {
    lobbies[lobbyId] = { users: [socket.id], bots: [], messages: [] };
    socket.join(lobbyId);
    io.emit('lobbyList', Object.keys(lobbies).map(id => ({
      id,
      participants: lobbies[id].users.length + lobbies[id].bots.length
    })));
  });

  socket.on('joinLobby', ({ lobbyId }) => {
    if (lobbies[lobbyId]) {
      lobbies[lobbyId].users.push(socket.id);
      socket.join(lobbyId);
      io.to(lobbyId).emit('system', `${socket.id} joined ${lobbyId}`);
    }
  });

  socket.on('addBot', ({ lobbyId }) => {
    if (!lobbies[lobbyId]) return;
    const botId = `AI-${Math.random().toString(36).substring(2, 8)}`;
    lobbies[lobbyId].bots.push(botId);
    io.to(lobbyId).emit('system', `${botId} joined the chat`);
    if (!lobbies[lobbyId].messages) lobbies[lobbyId].messages = [];
  });

  socket.on('message', async ({ lobbyId, user, text }) => {
    const msg = { user, text };
    io.to(lobbyId).emit('message', msg);

    if (!lobbies[lobbyId].messages) lobbies[lobbyId].messages = [];
    lobbies[lobbyId].messages.push(msg);

    for (const botId of lobbies[lobbyId].bots) {
      try {
        const contextMessages = lobbies[lobbyId].messages
          .filter(m => !m.user.includes("Trivia Bot"))
          .slice(-6)
          .map(m => ({
            role: m.user.startsWith("AI-") ? "assistant" : "user",
            content: m.text
          }));

        const promptIntro = {
          role: "system",
          content: "You are a friendly AI chatbot helping players in a multiplayer game lobby. Don't answer trivia questions unless asked directly. Keep your responses brief, human-like, and casual."
        };

        const response = await fetch("https://openrouter.ai/api/v1/chat/completions", {
          method: "POST",
          headers: {
            "Authorization": `Bearer ${OPENROUTER_API_KEY}`,
            "Content-Type": "application/json"
          },
          body: JSON.stringify({
            model: "anthropic/claude-3-sonnet-20240229",
            stream: true,
            messages: [promptIntro, ...contextMessages],
            max_tokens: 200,
            temperature: 0.7
          })
        });

        let fullMessage = '';
        response.body.on('data', (chunk) => {
          const raw = chunk.toString();
          const lines = raw.split("data: ").filter(line => line.trim().startsWith('{'));

          for (const line of lines) {
            try {
              const json = JSON.parse(line.trim());
              const delta = json?.choices?.[0]?.delta?.content;
              if (delta) {
                fullMessage += delta;
                io.to(lobbyId).emit("botTyping", { text: delta });
              }
            } catch (err) {
              console.error("Parse error:", err.message);
            }
          }
        });

        response.body.on('end', () => {
          io.to(lobbyId).emit("botMessage", { user: botId, text: fullMessage });
          lobbies[lobbyId].messages.push({ user: botId, text: fullMessage });
        });

      } catch (err) {
        console.error("OpenRouter Claude error:", err.message);
      }
    }
  });

  socket.on('disconnect', () => {
    console.log('Disconnected:', socket.id);
    for (const id in lobbies) {
      lobbies[id].users = lobbies[id].users.filter(u => u !== socket.id);
    }
  });
});

// Trivia game loop: send question to each lobby every 60s
setInterval(() => {
  for (const lobbyId in lobbies) {
    const lobby = lobbies[lobbyId];
    if (!lobby) continue;

    const trivia = triviaQuestions[Math.floor(Math.random() * triviaQuestions.length)];
    const triviaMsg = {
      user: "💡 Trivia Bot",
      text: `🎯 Trivia Time!\n${trivia.question}\nOptions: ${trivia.options.join(', ')}`
    };

    io.to(lobbyId).emit('message', triviaMsg);
    lobby.messages.push(triviaMsg);
  }
}, 60000);

server.listen(3000, () => console.log("Server running on http://localhost:3000"));
