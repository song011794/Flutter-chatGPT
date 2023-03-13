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

  final TextEditingController _textEditingController = TextEditingController();
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
            sendTimeout: const Duration(minutes: 3),
            connectTimeout: const Duration(minutes: 3),
            receiveTimeout: const Duration(minutes: 3)),
        isLogger: true);
  }

  @override
  void dispose() {
    _openAI.close();
    _tController.close();
    _inputValueStream.close();
    _scrollController.dispose();
    _textEditingController.dispose();
    _inputValue.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          centerTitle: true,
          title: const Text('ChatGPT 채팅'),
        ),
        body: Column(
          children: [
            Expanded(flex: 8, child: chatListWidget()),
            Expanded(flex: 2, child: textInputWidget()),
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
              if (index == chatList.length) {
                scrollToDown();
              }

              if (index != chatList.length) {
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
                return StreamBuilder<ChatCTResponse?>(
                    stream: _tController.stream,
                    builder: (context, snapshot) {
                      final data = snapshot.data;

                      if (snapshot.connectionState == ConnectionState.active) {
                        scrollToDown();

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
                            title: Text(gptAnswer, textAlign: TextAlign.start));
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
                    controller: _textEditingController,
                    onChanged: (value) => _inputValue.value = value,
                    onFieldSubmitted: (value) {
                      _inputValue.value = value;
                      requestGPT();
                    },
                    decoration: const InputDecoration(
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.all(Radius.circular(20)),
                            borderSide: BorderSide(color: Colors.blue))));
              },
            )),
            IconButton(onPressed: requestGPT, icon: const Icon(Icons.send))
          ],
        ),
      ),
    );
  }

  void scrollToDown() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(_scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeInOut);
      }
    });
  }

  void requestGPT() {
    if (_inputValue.value.isEmpty) {
      return;
    }
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

    _textEditingController.clear();
    scrollToDown();
  }
}
