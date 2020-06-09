import 'dart:async';
import 'package:http/http.dart' as http;

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' show join;
import 'package:path_provider/path_provider.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final cameras = await availableCameras();
  final firstCamera = cameras.first;

  runApp(
    MaterialApp(
      theme: ThemeData.dark(),
      home: TakePictureScreen(
        camera: firstCamera,
      ),
    ),
  );
}

// A screen that allows users to take a picture using a given camera.
class TakePictureScreen extends StatefulWidget {
  final CameraDescription camera;

  const TakePictureScreen({
    Key key,
    @required this.camera,
  }) : super(key: key);

  @override
  TakePictureScreenState createState() => TakePictureScreenState();
}

class TakePictureScreenState extends State<TakePictureScreen> {
  CameraController _controller;
  Future<void> _initializeControllerFuture;
  Timer timer;
  bool isRecording = false;

  @override
  void initState() {
    super.initState();
    _controller = CameraController(
      widget.camera,
      ResolutionPreset.ultraHigh,
    );

    _initializeControllerFuture = _controller.initialize();
  }

  @override
  void dispose() {
    _controller.dispose();
    timer.cancel();
    super.dispose();
  }

  void startRecording() async {
    await _initializeControllerFuture;
    setState(
      () {
        isRecording = true;
        timer = Timer.periodic(
          Duration(seconds: 2),
          (timer) async {
            try {
              final path = join(
                (await getTemporaryDirectory()).path,
                '${DateTime.now()}.png',
              );
              await _controller.takePicture(path);
              var uri = Uri.parse('http://192.168.1.8:8085/upload');
              var request = http.MultipartRequest('POST', uri);
              var multipartFile =
                  await http.MultipartFile.fromPath("image", path);

              request.files.add(multipartFile);

              request.send();
            } catch (e) {
              print(e);
            }
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(isRecording ? 'Recording' : 'Start recording'),
      ),
      body: FutureBuilder<void>(
        future: _initializeControllerFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.done) {
            return CameraPreview(_controller);
          } else {
            return Center(child: CircularProgressIndicator());
          }
        },
      ),
      floatingActionButton: FloatingActionButton(
        child: Icon(
          isRecording ? Icons.stop : Icons.camera_alt,
          color: Colors.red,
        ),
        onPressed: () async {
          if (isRecording) {
            setState(() {
              isRecording = false;
              timer.cancel();
            });
          } else {
            this.startRecording();
          }
        },
      ),
    );
  }
}
