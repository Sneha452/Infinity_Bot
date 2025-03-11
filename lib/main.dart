import 'dart:developer';
import 'dart:io';

import 'package:dash_chat_2/dash_chat_2.dart';
import 'package:flutter/material.dart';
import 'package:flutter_gemini/flutter_gemini.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'database_helper.dart';
import 'splash_screen.dart';

void main() {
  // Initialize the Gemini API with your API key
  Gemini.init(apiKey: 'AIzaSyCSkFVIuKkQgMJgsg1n3mBAxLJ2HWTNVwY');
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Infinity Bot',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      // Set the SplashScreen as the initial screen
      home: const SplashScreen(
        child: MyHomePage(title: 'Infinity Bot'),
      ),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}
class _MyHomePageState extends State<MyHomePage> {
  TextEditingController controller = TextEditingController();
  String results = "results to be shown here";
  SpeechToText _speechToText = SpeechToText();
  FlutterTts flutterTts = FlutterTts();

  bool _speechEnabled = false;
  bool isSidebarOpen = false;
  String _lastWords = '';
  bool isTTS = false;
  bool isDark = false;
  bool isLoading = false;

  // Chat management
  List<List<ChatMessage>> chatHistory = [[]];
  List<String> chatTitles = ['Chat 1'];
  int currentChatIndex = 0;
  List<ChatMessage> get currentMessages => chatHistory[currentChatIndex];

  // Sidebar toggle
  void toggleSidebar() {
    setState(() {
      isSidebarOpen = !isSidebarOpen;
    });
  }

  // Add new chat
  Future<void> saveChatTitle(int index, String title) async {
    await DatabaseHelper.instance.insertMessage(index, 'system', 'CHAT_TITLE:$title', false);
  }

  void addNewChat() async {
    setState(() {
      chatHistory.add([]);
      chatTitles.add('Chat ${chatHistory.length}');
      currentChatIndex = chatHistory.length - 1;
    });
    await saveChatTitle(currentChatIndex, chatTitles.last);
  }

  // Open existing chat
  void openChat(int index) {
    setState(() {
      currentChatIndex = index;
    });
  }

  // Delete existing chat
  void deleteChat(int index) async {
    setState(() {
      if (chatHistory.length > 1) {
        chatHistory.removeAt(index);
        chatTitles.removeAt(index);
        if (currentChatIndex >= chatHistory.length) {
          currentChatIndex = chatHistory.length - 1;
        }
      }
    });
    await DatabaseHelper.instance.deleteChat(index);
  }

  late final Gemini gemini;

  @override
  void initState() {
    super.initState();
    gemini = Gemini.instance;
    _initSpeech();
    loadSpeakData();
    loadModels();
    loadChatHistory();
  }

  Future<void> loadChatHistory() async {
    // Fetch all chat IDs from the database
    final chatIds = await DatabaseHelper.instance.getAllChatIds();

    // Reset chat history and titles
    chatHistory = [];
    chatTitles = [];

    for (final chatId in chatIds) {
      // Fetch messages for each chat
      final messages = await DatabaseHelper.instance.getMessagesForChat(chatId);

      // Convert database messages to ChatMessage objects
      final chatMessages = messages.map((msg) {
        return ChatMessage(
          user: ChatUser(id: msg['user_id']),
          text: msg['message'],
          createdAt: DateTime.fromMillisecondsSinceEpoch(msg['timestamp']),
        );
      }).toList();

      // Add to chat history
      chatHistory.add(chatMessages);
      chatTitles.add('Chat ${chatId + 1}');
    }

    // Set the current chat index to the last opened chat
    if (chatHistory.isEmpty) {
      chatHistory.add([]);
      chatTitles.add('Chat 1');
    }

    setState(() {
      currentChatIndex = chatHistory.length - 1;
    });
  }

  void loadModels() {
    gemini
        .listModels()
        .then((models) => print(models))
        .catchError((e) => log('listModels', error: e));
  }

  Future<void> loadSpeakData() async {
    List<dynamic> languages = await flutterTts.getLanguages;
    List<dynamic> voices = await flutterTts.getVoices;

    languages.forEach((e) {
      print("language=$e");
    });
    voices.forEach((e) {
      print("voice=$e");
    });

    await flutterTts.setLanguage("en-US");
    await flutterTts.setVoice({"name": "en-us-x-tpf-local", "locale": "en-US"});
  }

  void _initSpeech() async {
    _speechEnabled = await _speechToText.initialize();
    setState(() {});
  }

  void _startListening() async {
    await _speechToText.listen(onResult: _onSpeechResult);
    setState(() {});
  }

  void _stopListening() async {
    await _speechToText.stop();
    setState(() {});
  }
  Future<void> stopSpeechOutput() async {
    await flutterTts.stop();
    setState(() {
      isLoading = false; // Ensure loading spinner stops if speech is interrupted
    });
  }

  void _onSpeechResult(SpeechRecognitionResult result) {
    setState(() {
      _lastWords = result.recognizedWords;
      controller.text = _lastWords;
      if (result.finalResult) {
        processInput();
      }
    });
  }

  bool imageSelected = false;
  late File selectedImage;
  final ImagePicker imagePicker = ImagePicker();

  Future<void> pickImage() async {
    final XFile? image = await imagePicker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      setState(() {
        imageSelected = true;
        selectedImage = File(image.path);
        ChatMessage message = ChatMessage(
          user: user,
          createdAt: DateTime.now(),
          text: "",
          medias: [ChatMedia(url: image.path, fileName: image.name, type: MediaType.image)],
        );
        currentMessages.insert(0, message);
      });
    }
  }

  List<Content> contentList = [];

  Future<void> processInput() async {
    String userInput = controller.text.trim();
    if (userInput.isEmpty) return;

    controller.clear();
    ChatMessage message = ChatMessage(user: user, createdAt: DateTime.now(), text: userInput);
    await DatabaseHelper.instance.insertMessage(currentChatIndex, user.id, userInput, true);
    setState(() {
      currentMessages.insert(0, message);
      isLoading = true;
    });

    if (imageSelected) {
      try {
        final response = await Gemini.instance.textAndImage(
          text: userInput,
          images: [selectedImage.readAsBytesSync()],
        );
        results = response?.content?.parts?.last.text ?? '';
        if (isTTS) {
          await flutterTts.speak(results);
        }
        setState(() {
          imageSelected = false;
          ChatMessage botMessage = ChatMessage(
            user: geminiUser,
            createdAt: DateTime.now(),
            text: results,
          );
          currentMessages.insert(0, botMessage);
        });
        await DatabaseHelper.instance.insertMessage(currentChatIndex, geminiUser.id, results, false);
      } catch (e) {
        log('textAndImageInput error', error: e);
      }
    } else {
      results = "";
      await for (final value in Gemini.instance.streamGenerateContent(
        userInput,
        generationConfig: GenerationConfig(
          temperature: 1.0,
          maxOutputTokens: 1000,
        ),
        safetySettings: [
          SafetySetting(
            category: SafetyCategory.harassment,
            threshold: SafetyThreshold.blockLowAndAbove,
          ),
          SafetySetting(
            category: SafetyCategory.hateSpeech,
            threshold: SafetyThreshold.blockOnlyHigh,
          ),
        ],
      )) {
        setState(() {
          results += value.output ?? '';
          // Update the last message if it's from the bot, otherwise add a new one
          if (currentMessages.isNotEmpty && currentMessages[0].user.id == geminiUser.id) {
            currentMessages[0] = ChatMessage(
              user: geminiUser,
              createdAt: DateTime.now(),
              text: results,
            );
          } else {
            currentMessages.insert(0, ChatMessage(
              user: geminiUser,
              createdAt: DateTime.now(),
              text: results,
            ));
          }
        });
      }
      if (isTTS) {
        await flutterTts.speak(results);
      }
      await DatabaseHelper.instance.insertMessage(currentChatIndex, geminiUser.id, results, false);
    }

    setState(() {
      isLoading = false;
    });
  }

  void handleDone() {
    if (isTTS) {
      flutterTts.speak(results);
    }
    setState(() {
      isLoading = false;
    });
  }

  // Chat Users
  ChatUser user = ChatUser(id: '1', firstName: 'User');
  ChatUser geminiUser = ChatUser(id: '2', firstName: 'Infinity Bot');

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).primaryColor,
        title: Text(
          widget.title,
          style: TextStyle(color: Colors.white),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: Icon(isTTS ? Icons.volume_up : Icons.volume_off, color: Colors.white),
      onPressed: () async {
        if (isTTS) {
          // Stop speech output
          await flutterTts.stop();
          setState(() {
            isTTS = false;
          });
        } else {
          // Enable TTS mode
          setState(() {
            isTTS = true;
          });
          if (results.isNotEmpty) {
            await flutterTts.speak(results); // Speak current results if available
          }
        }
      },
    ),
          IconButton(
            icon: Icon(isSidebarOpen ? Icons.close : Icons.menu, color: Colors.white),
            onPressed: toggleSidebar,
          ),
        ],
      ),
      body: Row(
        children: [
          // Sidebar for chats
          AnimatedContainer(
            duration: Duration(milliseconds: 300),
            width: isSidebarOpen ? 250 : 0,
            color: Colors.grey.shade200,
            child: isSidebarOpen
                ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ListTile(
                  title: Text(
                    'Chats',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  trailing: IconButton(
                    icon: Icon(Icons.add),
                    onPressed: addNewChat,
                  ),
                ),
                Expanded(
                  child: ListView.builder(
                    itemCount: chatTitles.length,
                    itemBuilder: (context, index) {
                      return ListTile(
                        title: Text(chatTitles[index]),
                        onTap: () => openChat(index),
                        selected: index == currentChatIndex,
                        leading: Icon(Icons.chat),
                        trailing: IconButton(
                          icon: Icon(Icons.delete),
                          onPressed: () => deleteChat(index),
                        ),
                      );
                    },
                  ),
                ),
              ],
            )
                : SizedBox.shrink(),
          ),
          // Main Chat UI
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                image: DecorationImage(
                  image: AssetImage("assets/bg.jpg"),
                  fit: BoxFit.cover,
                  colorFilter: isDark
                      ? ColorFilter.mode(Colors.black.withOpacity(0.6), BlendMode.darken)
                      : null,
                ),
              ),
              child: Column(
                children: [
                  Expanded(
                    child: DashChat(
                      currentUser: user,
                      onSend: (ChatMessage m) {},
                      messages: currentMessages,
                      readOnly: true,
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(5.0),
                    child: Row(
                      children: [
                        Expanded(
                          child: Card(
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(25)),
                            color: Colors.white,
                            child: Padding(
                              padding: const EdgeInsets.only(left: 8.0, right: 8),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: TextField(
                                      controller: controller,
                                      decoration: InputDecoration(
                                          border: InputBorder.none,
                                          hintText: "Ask InfinityBot"),
                                    ),
                                  ),
                                  InkWell(
                                    child: Icon(Icons.image),
                                    onTap: pickImage,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        ElevatedButton(
                          child: const Icon(Icons.mic, color: Colors.white),
                          onPressed: _startListening,
                          style: ElevatedButton.styleFrom(
                            shape: CircleBorder(),
                            backgroundColor: Colors.green.shade400,
                            padding: EdgeInsets.all(10),
                          ),
                        ),
                        ElevatedButton(
                          child: isLoading
                              ? CircularProgressIndicator(color: Colors.white)
                              : const Icon(Icons.send, color: Colors.white),
                          onPressed: isLoading ? null : processInput,
                          style: ElevatedButton.styleFrom(
                            shape: CircleBorder(),
                            backgroundColor: Theme.of(context).primaryColor,
                            padding: EdgeInsets.all(10),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}