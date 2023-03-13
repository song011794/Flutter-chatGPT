import 'dart:async';

import 'package:chat_gpt_sdk/chat_gpt_sdk.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class GptImageGeneraterScreen extends StatefulWidget {
  const GptImageGeneraterScreen({key}) : super(key: key);

  @override
  State<GptImageGeneraterScreen> createState() =>
      _GptImageGeneraterScreenState();
}

class _GptImageGeneraterScreenState extends State<GptImageGeneraterScreen> {
  final ValueNotifier<String> _inputValue = ValueNotifier<String>('');

  final TextEditingController _textEditingController = TextEditingController();
  final StreamController<String> _inputValueStream = StreamController<String>();
  final ScrollController _scrollController =
      ScrollController(initialScrollOffset: 0);
  final StreamController<GenImgResponse?> _tController =
      StreamController<GenImgResponse?>.broadcast();
  late final OpenAI _openAI;
  List<Map<String, dynamic>> chatList = [];

  @override
  void initState() {
    super.initState();
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
          title: const Text('ChatGPT Image Generater'),
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
                        title: Image.network(
                          chatList[index]['msg']!,
                          fit: BoxFit.fill,
                          loadingBuilder: (context, child, loadingProgress) {
                            if (loadingProgress == null) {
                              return child;
                            }
                            return Center(
                              child: SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  color: Colors.red,
                                  value: loadingProgress.expectedTotalBytes !=
                                          null
                                      ? loadingProgress.cumulativeBytesLoaded /
                                          loadingProgress.expectedTotalBytes!
                                      : null,
                                ),
                              ),
                            );
                          },
                        ));
              } else {
                return StreamBuilder<GenImgResponse?>(
                    stream: _tController.stream,
                    builder: (context, snapshot) {
                      final data = snapshot.data;

                      if (snapshot.connectionState == ConnectionState.active) {
                        scrollToDown();

                        String gptAnswer = data!.data!.last!.url!;

                        chatList.add({'user': 'gpt', 'msg': gptAnswer});

                        return ListTile(
                            leading: CircleAvatar(
                                backgroundColor: Colors.transparent,
                                child: Image.asset(
                                  'images/chatgpt_logo.png',
                                  color: Colors.black,
                                )),
                            title: Image.network(
                              gptAnswer,
                              fit: BoxFit.fill,
                              loadingBuilder:
                                  (context, child, loadingProgress) {
                                if (loadingProgress == null) {
                                  return child;
                                }
                                return Center(
                                  child: SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      color: Colors.red,
                                      value:
                                          loadingProgress.expectedTotalBytes !=
                                                  null
                                              ? loadingProgress
                                                      .cumulativeBytesLoaded /
                                                  loadingProgress
                                                      .expectedTotalBytes!
                                              : null,
                                    ),
                                  ),
                                );
                              },
                            ));
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

    final request = GenerateImage(_inputValue.value, 1);

    _openAI.generateImageStream(request).asBroadcastStream().listen((it) {
      _tController.sink.add(it);
    });

    _textEditingController.clear();
    scrollToDown();
  }
}
