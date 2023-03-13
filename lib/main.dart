import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:gpt/gpt.dart';

import 'gpt_image_generater.dart';

void main() async {
  await dotenv.load(fileName: ".env");
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ChatGPT',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: const MyHomePage(title: 'ChatGPT APP'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({key, required this.title}) : super(key: key);
  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          centerTitle: true,
          title: Text(widget.title),
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              TextButton(
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    color: Colors.deepOrange,
                    child: const Text(
                      '채팅하기',
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                  onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (context) => const GptScreen()),
                      )),
              TextButton(
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    color: Colors.deepPurple,
                    child: const Text(
                      'Image Generater',
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                  onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (context) =>
                                const GptImageGeneraterScreen()),
                      )),
            ],
          ),
        ));
  }
}
