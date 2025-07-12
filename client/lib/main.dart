import 'package:flutter/material.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'AI Chat Game',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: const LobbyScreen(),
    );
  }
}

class LobbyScreen extends StatefulWidget {
  const LobbyScreen({super.key});

  @override
  _LobbyScreenState createState() => _LobbyScreenState();
}

class _LobbyScreenState extends State<LobbyScreen> {
  late IO.Socket socket;
  List<dynamic> lobbies = [];
  final TextEditingController lobbyIdController = TextEditingController();
  late final String userId;

  @override
  void initState() {
    super.initState();
    userId = 'User${DateTime.now().millisecondsSinceEpoch}';
    initSocket();
  }

  void initSocket() {
    socket = IO.io('http://192.168.1.159:3000', <String, dynamic>{
      'transports': ['websocket'],
      'autoConnect': false,
    });
    socket.connect();

    socket.onConnect((_) {
      print('✅ Connected to server');
      socket.emit('getLobbies');
    });

    socket.on('lobbyList', (data) {
      if (!mounted) return;
      setState(() {
        lobbies = data;
      });
    });

    socket.onDisconnect((_) => print('❌ Disconnected from server'));
  }

  void createLobby() {
    final lobbyId = lobbyIdController.text.trim();
    if (lobbyId.isNotEmpty) {
      socket.emit('createLobby', {'lobbyId': lobbyId});
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ChatScreen(
            socket: socket,
            lobbyId: lobbyId,
            userId: userId,
          ),
        ),
      );
    }
  }

  void joinLobby(String lobbyId) {
    socket.emit('joinLobby', {'lobbyId': lobbyId});
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ChatScreen(
          socket: socket,
          lobbyId: lobbyId,
          userId: userId,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Lobbies')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(10),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: lobbyIdController,
                    decoration: const InputDecoration(labelText: 'New Lobby ID'),
                  ),
                ),
                ElevatedButton(
                  onPressed: createLobby,
                  child: const Text('Create'),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: lobbies.length,
              itemBuilder: (context, index) {
                final lobby = lobbies[index];
                return ListTile(
                  title: Text('Lobby: ${lobby['id']}'),
                  subtitle: Text('${lobby['participants']} participant(s)'),
                  onTap: () => joinLobby(lobby['id']),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class ChatScreen extends StatefulWidget {
  final IO.Socket socket;
  final String lobbyId;
  final String userId;

  const ChatScreen({
    super.key,
    required this.socket,
    required this.lobbyId,
    required this.userId,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController controller = TextEditingController();
  final List<Map<String, dynamic>> messages = [];
  String typingBuffer = '';

  @override
  void initState() {
    super.initState();

    widget.socket.emit('joinLobby', {
      'lobbyId': widget.lobbyId,
      'userId': widget.userId,
    });

    widget.socket.on('message', (data) {
      if (!mounted) return;
      setState(() {
        messages.add(Map<String, dynamic>.from(data));
      });
    });

    widget.socket.on('system', (data) {
      if (!mounted) return;
      setState(() {
        messages.add({'userId': 'System', 'message': data});
      });
    });

    widget.socket.on('botTyping', (data) {
      if (!mounted) return;
      setState(() {
        typingBuffer += data['text'] ?? '';
      });
    });

    widget.socket.on('botMessage', (data) {
      if (!mounted) return;
      setState(() {
        final botName = data['user'] ?? 'AI Bot';
        messages.add({'userId': botName, 'message': data['text']});
        typingBuffer = '';
      });
    });

    widget.socket.on('trivia', (data) {
      if (!mounted) return;
      setState(() {
        messages.add({
          'userId': 'Trivia Bot',
          'message': "🎯 Trivia Time!\n${data['question']}\nOptions: ${data['options'].join(', ')}",
        });
      });
    });
  }

  @override
  void dispose() {
    controller.dispose();
    widget.socket.off('message');
    widget.socket.off('system');
    widget.socket.off('botTyping');
    widget.socket.off('botMessage');
    widget.socket.off('trivia');
    super.dispose();
  }

  void sendMessage() {
    final msg = controller.text.trim();
    if (msg.isEmpty) return;

    widget.socket.emit('message', {
      'lobbyId': widget.lobbyId,
      'user': widget.userId,
      'text': msg,
    });

    setState(() {
      controller.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    final allMessages = List<Map<String, dynamic>>.from(messages);
    if (typingBuffer.isNotEmpty) {
      allMessages.add({'userId': 'AI Bot', 'message': typingBuffer});
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('Lobby: ${widget.lobbyId}'),
        actions: [
          IconButton(
            icon: const Icon(Icons.smart_toy),
            tooltip: 'Add AI Bot',
            onPressed: () {
              widget.socket.emit('addBot', {'lobbyId': widget.lobbyId});
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              itemCount: allMessages.length,
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemBuilder: (context, index) {
                final msg = allMessages[index];
                final sender = msg['userId'] ?? msg['user'] ?? 'Unknown';
                final content = msg['message'] ?? msg['text'] ?? '';

                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      '$sender:\n$content',
                      style: TextStyle(
                        color: sender == 'System'
                            ? Colors.grey
                            : sender == 'Trivia Bot'
                            ? Colors.deepPurple
                            : Colors.black87,
                        fontWeight: sender == 'System'
                            ? FontWeight.w500
                            : FontWeight.normal,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: controller,
                    onSubmitted: (_) => sendMessage(),
                    decoration: const InputDecoration(hintText: 'Enter message'),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: sendMessage,
                  child: const Text('Send'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
