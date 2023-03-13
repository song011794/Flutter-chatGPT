import 'dart:async';
import 'dart:math';

import 'package:chat_gpt_sdk/chat_gpt_sdk.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class GptScreen extends StatefulWidget {
  const GptScreen({key}) : super(key: key);

  @override
  State<GptScreen> createState() => _GptScreenState();
}

class _GptScreenState extends State<GptScreen> {
  final ValueNotifier<String> _inputValue = ValueNotifier<String>('');
  final StreamController<String> _inputValueStream = StreamController<String>();

  final ScrollController _scrollController =
      ScrollController(initialScrollOffset: 0);
  late final StreamController<ChatCTResponse?> _tController;
  late final OpenAI _openAI;
  List<Map<String, dynamic>> chatList = [];

  @override
  void initState() {
    super.initState();
    _tController = StreamController<ChatCTResponse?>.broadcast();

    _openAI = OpenAI.instance.build(
        token: dotenv.env['GPT_TOKEN'],
        baseOption: HttpSetup(
            sendTimeout: const Duration(seconds: 30),
            connectTimeout: const Duration(seconds: 30),
            receiveTimeout: const Duration(seconds: 30)),
        isLogger: true);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(),
        body: Column(
          children: [
            Expanded(flex: 9, child: chatListWidget()),
            Expanded(flex: 1, child: textInputWidget()),
          ],
        ));
  }

  Widget chatListWidget() {
    return StreamBuilder<String>(
      stream: _inputValueStream.stream,
      builder: (context, snapshot) {
        if (snapshot.hasData) {
          return ListView.separated(
            separatorBuilder: (context, index) => const Divider(),
            controller: _scrollController,
            scrollDirection: Axis.vertical,
            itemCount: chatList.length + 1,
            itemBuilder: (context, index) {
              if (index != chatList.length) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (_scrollController.hasClients) {
                    _scrollController.animateTo(
                        _scrollController.position.maxScrollExtent,
                        duration: const Duration(milliseconds: 200),
                        curve: Curves.easeInOut);
                  }
                });

                return chatList[index]['user'] == 'user'
                    ? ListTile(
                        trailing: const CircleAvatar(child: Text('ME')),
                        title: Text(chatList[index]['msg']!,
                            textAlign: TextAlign.end))
                    : ListTile(
                        leading: CircleAvatar(
                            backgroundColor: Colors.transparent,
                            child: Image.asset(
                              'images/chatgpt_logo.png',
                              color: Colors.black,
                            )),
                        title: Text(chatList[index]['msg']!,
                            textAlign: TextAlign.start));
              } else {
                return
                    // StreamBuilder<CTResponse?>(
                    StreamBuilder<ChatCTResponse?>(
                        stream: _tController.stream,
                        builder: (context, snapshot) {
                          final data = snapshot.data;

                          if (snapshot.connectionState ==
                              ConnectionState.active) {
                            WidgetsBinding.instance.addPostFrameCallback((_) {
                              if (_scrollController.hasClients) {
                                _scrollController.animateTo(
                                    _scrollController.position.maxScrollExtent,
                                    duration: const Duration(milliseconds: 200),
                                    curve: Curves.easeInOut);
                              }
                            });

                            int randomNumber =
                                Random().nextInt(data!.choices.length);

                            String gptAnswer =
                                data.choices[randomNumber].message.content;

                            chatList.add({'user': 'gpt', 'msg': gptAnswer});

                            return ListTile(
                                leading: CircleAvatar(
                                    backgroundColor: Colors.transparent,
                                    child: Image.asset(
                                      'images/chatgpt_logo.png',
                                      color: Colors.black,
                                    )),
                                title: Text(gptAnswer,
                                    textAlign: TextAlign.start));
                          } else if (snapshot.connectionState ==
                              ConnectionState.waiting) {
                            return ListTile(
                                leading: CircleAvatar(
                                    backgroundColor: Colors.transparent,
                                    child: Image.asset(
                                      'images/chatgpt_logo.png',
                                      color: Colors.black,
                                    )),
                                title: const Center(
                                  child: SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator()),
                                ));
                          } else {
                            return Container();
                          }
                        });
              }
            },
          );
        }

        return Container();
      },
    );
  }

  Widget textInputWidget() {
    return SizedBox(
      width: double.infinity,
      height: double.infinity,
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Row(
          children: [
            Expanded(
                child: ValueListenableBuilder(
              valueListenable: _inputValue,
              builder: (BuildContext context, value, Widget? child) {
                return TextFormField(
                  initialValue: _inputValue.value,
                  onChanged: (value) => _inputValue.value = value,
                );
              },
            )),
            IconButton(
                onPressed: () async {
                  chatList.add({'user': 'user', 'msg': _inputValue.value});
                  _inputValueStream.sink.add(_inputValue.value);

                  // final models = await _openAI.listModel();

                  final request = ChatCompleteText(
                    messages: [
                      Map.of({"role": "user", "content": _inputValue.value})
                    ],
                    maxToken: 500,
                    model: kChatGptTurbo0301Model, //charGPT 3.5 Turbo
                  );

                  _openAI
                      .onChatCompletionStream(request: request)
                      .asBroadcastStream()
                      .listen((res) {
                    _tController.sink.add(res);
                  });
                },
                icon: const Icon(Icons.send))
          ],
        ),
      ),
    );
  }
}
