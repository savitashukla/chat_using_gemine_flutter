import 'package:flutter/material.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

import 'secrets.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Only load a local .env asset when not running on the web. On web, fetching
  // assets/.env can cause a 404 in the browser if the file is not present.
  if (!kIsWeb) {
    try {
      await dotenv.load(fileName: '.env');
    } catch (_) {}
  }

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Chat App',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
      ),
      home: const ChatPage(),
    );
  }
}

class ChatMessage {
  final String text;
  final bool isUser;
  final DateTime time;

  ChatMessage({required this.text, this.isUser = false})
    : time = DateTime.now();
}

class ChatPage extends StatefulWidget {
  const ChatPage({super.key});

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final List<ChatMessage> _messages = [];
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _isSending = false;

  // Speech-to-text fields
  late SpeechToText _speech;
  bool _speechAvailable = false;
  bool _isListeningVoice = false;

  @override
  void initState() {
    super.initState();
    _speech = SpeechToText();
    _initSpeech();
  }

  Future<void> _initSpeech() async {
    try {
      _speechAvailable = await _speech.initialize(
        onStatus: (status) {
          // optional: handle status updates
        },
        onError: (error) {
          // optional: handle errors
        },
      );
      setState(() {});
    } catch (e) {
      _speechAvailable = false;
      setState(() {});
    }
  }

  void _startListening() {
    if (!_speechAvailable) return;
    _speech.listen(onResult: (result) {
      setState(() {
        _controller.text = result.recognizedWords;
        // move cursor to end
        _controller.selection = TextSelection.fromPosition(TextPosition(offset: _controller.text.length));
      });
      if (result.finalResult) {
        _stopListening();
      }
    });
    setState(() {
      _isListeningVoice = true;
    });
  }

  void _stopListening() {
    _speech.stop();
    setState(() {
      _isListeningVoice = false;
    });
  }

  Future<void> _sendMessage() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;

    setState(() {
      _messages.add(ChatMessage(text: text, isUser: true));
      _controller.clear();
      _isSending = true;
    });

    _scrollToBottom();
    // ensure API key is available
    final apiKey = getGoogleGenerativeApiKey();
    if (apiKey == null || apiKey.isEmpty) {
      setState(() {
        _messages.add(ChatMessage(
            text: 'API key missing. Provide GOOGLE_GENERATIVE_API_KEY via .env or --dart-define',
            isUser: false));
        _isSending = false;
      });
    }

    try {
      final model = GenerativeModel(
        model: 'gemini-2.5-flash', // adjust to a supported model if required
        apiKey: apiKey,
      );

      final resp = await model.generateContent([Content.text(text)]);

      print("call data ${resp.text}");

      setState(() {
        _messages.add(ChatMessage(text: resp.text ?? "", isUser: false));
        _isSending = false;
      });
    } catch (e, st) {
      // Log detailed error to console for debugging
      print('Request error type: ${e.runtimeType}');
      print('Request error: $e');
      print('Stack trace: $st');

      // Show concise message to the user in chat
      setState(() {
        _messages.add(ChatMessage(
            text: 'Request failed: ${e.runtimeType} - ${e.toString()}',
            isUser: false));
        _isSending = false;
      });
    }

    _scrollToBottom();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  void dispose() {
    // stop speech if active
    try {
      if (_isListeningVoice) {
        _speech.stop();
      }
    } catch (_) {}
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Widget _buildMessageBubble(ChatMessage msg) {
    final alignment = msg.isUser ? Alignment.centerRight : Alignment.centerLeft;
    final color = msg.isUser ? Colors.blueAccent : Colors.grey.shade200;
    final textColor = msg.isUser ? Colors.white : Colors.black87;

    return Align(
      alignment: alignment,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.75,
        ),
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 6.0, horizontal: 8.0),
          padding: const EdgeInsets.symmetric(vertical: 10.0, horizontal: 14.0),
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(12.0),
          ),
          child: Text(msg.text, style: TextStyle(color: textColor)),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Chat App'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView.builder(
                controller: _scrollController,
                padding: const EdgeInsets.symmetric(vertical: 12.0),
                itemCount: _messages.length,
                itemBuilder: (context, index) {
                  final msg = _messages[index];
                  return _buildMessageBubble(msg);
                },
              ),
            ),
            const Divider(height: 1.0),
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 8.0,
                vertical: 8.0,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _sendMessage(),
                      decoration: const InputDecoration(
                        hintText: 'Type a message',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.all(Radius.circular(20.0)),
                        ),
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 12.0,
                          vertical: 8.0,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8.0),
                  // Microphone button for speech input
                  IconButton(
                    onPressed: _speechAvailable
                        ? () {
                            if (!_isListeningVoice) {
                              _startListening();
                            } else {
                              _stopListening();
                            }
                          }
                        : null,
                    icon: Icon(_isListeningVoice ? Icons.mic : Icons.mic_none),
                  ),
                  const SizedBox(width: 8.0),
                  _isSending
                      ? const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 12.0),
                          child: SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(strokeWidth: 2.5),
                          ),
                        )
                      : IconButton(
                          onPressed: _sendMessage,
                          icon: const Icon(Icons.send),
                        ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
