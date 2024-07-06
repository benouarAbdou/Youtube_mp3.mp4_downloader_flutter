import 'dart:ffi';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:media_store_plus/media_store_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Flutter Demo',
      theme: ThemeData(
        useMaterial3: false,
      ),
      home: const MyHomePage(),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key});

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  final TextEditingController _controller = TextEditingController();
  String _selectedFormat = 'MP4';
  bool _isDownloading = false;

  void _selectFormat(String format) {
    setState(() {
      _selectedFormat = format;
    });
  }

  void _downloadVideo(String url) async {
    if (await Permission.storage.request().isGranted) {
      setState(() {
        _isDownloading = true;
      });

      try {
        var ytExplode = YoutubeExplode();
        var video = await ytExplode.videos.get(url);
        var manifest =
            await ytExplode.videos.streamsClient.getManifest(video.id);
        var streamInfo = _selectedFormat == 'MP3'
            ? manifest.audioOnly.withHighestBitrate()
            : manifest.muxed.withHighestBitrate();
        var stream = ytExplode.videos.streamsClient.get(streamInfo);
        var videoTitle = video.title
            .replaceAll(RegExp(r'[^\w\s-]'), '')
            .trim()
            .replaceAll(RegExp(r'\s+'), '_');
        videoTitle =
            videoTitle.length > 50 ? videoTitle.substring(0, 50) : videoTitle;

        Directory? directory;
        if (Platform.isAndroid) {
          directory = Directory('/storage/emulated/0/Download');
        } else if (Platform.isIOS) {
          directory = await getApplicationDocumentsDirectory();
        }

        if (directory != null) {
          var savePath =
              '${directory.path}/$videoTitle.${_selectedFormat.toLowerCase()}';
          var file = File(savePath);
          var output = file.openWrite();

          await for (var data in stream) {
            output.add(data);
          }

          await output.close();

          ytExplode.close();

          setState(() {
            _isDownloading = false;
          });

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text(
                    '${_selectedFormat.toUpperCase()} saved to $savePath')),
          );

          // For iOS, you might need to make the file available via the Files app
          if (Platform.isIOS) {
            // Use a plugin like share_plus to make the file accessible
          }
        } else {
          throw Exception('Could not access storage directory');
        }
      } catch (e) {
        setState(() {
          _isDownloading = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${e.toString()}')),
        );
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Storage permission denied')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                borderRadius: BorderRadius.circular(10),
              ),
              child: TextField(
                controller: _controller,
                onTapOutside: (event) {
                  FocusManager.instance.primaryFocus?.unfocus();
                },
                decoration: const InputDecoration(
                  hintText: "Enter youtube link/url..",
                  prefixIcon: Icon(Icons.search),
                  contentPadding: EdgeInsets.all(16),
                  border: OutlineInputBorder(
                    borderSide: BorderSide(color: Colors.grey, width: 1.0),
                    borderRadius: BorderRadius.all(Radius.circular(10)),
                  ),
                ),
              ),
            ),
            /*const SizedBox(
              height: 10,
            ),
            GestureDetector(
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: const BoxDecoration(
                  color: Colors.lightBlue,
                  borderRadius: BorderRadius.all(Radius.circular(10)),
                ),
                width: MediaQuery.sizeOf(context).width,
                child: const Text(
                  "Generate video content",
                  style: TextStyle(color: Colors.white),
                  textAlign: TextAlign.center,
                ),
              ),
            ),*/
            const SizedBox(
              height: 10,
            ),
            Row(
              mainAxisSize: MainAxisSize.max,
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () => _selectFormat('MP4'),
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: _selectedFormat == 'MP4'
                            ? Colors.lightBlue
                            : Colors.grey[400],
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(10),
                          bottomLeft: Radius.circular(10),
                        ),
                      ),
                      child: const Text(
                        "MP4",
                        style: TextStyle(color: Colors.white),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: GestureDetector(
                    onTap: () => _selectFormat('MP3'),
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: _selectedFormat == 'MP3'
                            ? Colors.lightBlue
                            : Colors.grey[400],
                        borderRadius: const BorderRadius.only(
                          topRight: Radius.circular(10),
                          bottomRight: Radius.circular(10),
                        ),
                      ),
                      child: const Text(
                        "MP3",
                        style: TextStyle(color: Colors.white),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(
              height: 10,
            ),
            GestureDetector(
              onTap: () => _downloadVideo(_controller.text),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: const BoxDecoration(
                  color: Colors.lightBlue,
                  borderRadius: BorderRadius.all(Radius.circular(10)),
                ),
                width: MediaQuery.sizeOf(context).width,
                child: _isDownloading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text(
                        "Download",
                        style: TextStyle(color: Colors.white),
                        textAlign: TextAlign.center,
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
