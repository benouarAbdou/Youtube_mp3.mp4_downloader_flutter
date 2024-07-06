import 'dart:async';
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
        fontFamily: 'Folks',
        colorScheme: ColorScheme.fromSwatch().copyWith(
          primary: const Color(0xFF58C2FF),
        ),
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
  final List<_DownloadTask> _downloadTasks = [];
  bool _isDownloadInProgress = false;

  void _selectFormat(String format) {
    setState(() {
      _selectedFormat = format;
    });
  }

  void _downloadVideo(String url) async {
    if (_isDownloadInProgress) {
      return; // Don't start a new download if one is already in progress
    }
    setState(() {
      _isDownloadInProgress = true;
    });
    _controller.clear();
    if (await Permission.storage.request().isGranted) {
      try {
        var ytExplode = YoutubeExplode();
        var video = await ytExplode.videos.get(url);
        var manifest =
            await ytExplode.videos.streamsClient.getManifest(video.id);
        var streamInfo = _selectedFormat == 'MP3'
            ? manifest.audioOnly.withHighestBitrate()
            : manifest.muxed.withHighestBitrate();
        var downloadStream = ytExplode.videos.streamsClient.get(streamInfo);
        var videoTitle = video.title
            .replaceAll(RegExp(r'[^\w\s-]'), '')
            .trim()
            .replaceAll(RegExp(r'\s+'), '_');
        videoTitle =
            videoTitle.length > 50 ? videoTitle.substring(0, 50) : videoTitle;

        Directory? directory;
        if (Platform.isAndroid) {
          directory = Directory('/storage/emulated/0/ytbinstaDownloader');
        } else if (Platform.isIOS) {
          directory = await getApplicationDocumentsDirectory();
        }

        if (directory != null) {
          if (!await directory.exists()) {
            await directory.create(recursive: true);
          }

          var savePath =
              '${directory.path}/$videoTitle.${_selectedFormat.toLowerCase()}';
          var file = File(savePath);
          var output = file.openWrite();

          var totalSize = streamInfo.size.totalBytes;
          var downloadedBytes = 0;
          var timer = Timer.periodic(const Duration(seconds: 1), (timer) {
            var downloadSpeed =
                (downloadedBytes / timer.tick) / (1024 * 1024); // MB/s
            var progress = downloadedBytes / totalSize;
            setState(() {
              _downloadTasks.last.progress = progress;
              _downloadTasks.last.downloadedMB =
                  downloadedBytes / (1024 * 1024); // Convert to MB
              _downloadTasks.last.downloadSpeed = downloadSpeed;
            });
          });

          var subscription = downloadStream.listen(
            (data) {
              output.add(data);
              downloadedBytes += data.length;
            },
            onDone: () async {
              await output.close();
              ytExplode.close();
              timer.cancel();
              setState(() {
                _downloadTasks.last.isDownloading = false;
                _downloadTasks.last.progress =
                    1.0; // Ensure progress reaches 100%
                _isDownloadInProgress = false; // Reset the flag
              });

              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                    content: Text(
                        '${_selectedFormat.toUpperCase()} saved to $savePath')),
              );
            },
            onError: (e) {
              setState(() {
                _downloadTasks.last.isDownloading = false;
                _isDownloadInProgress = false; // Reset the flag
              });
              timer.cancel();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Error: ${e.toString()}')),
              );
            },
            cancelOnError: true,
          );

          setState(() {
            _downloadTasks.add(_DownloadTask(
              url: url,
              selectedFormat: _selectedFormat,
              isDownloading: true,
              progress: 0.0,
              downloadedMB: 0.0,
              totalSizeMB: totalSize / (1024 * 1024),
              downloadSpeed: 0.0,
              videoTitle: videoTitle,
              thumbnailUrl: video.thumbnails.standardResUrl,
              subscription: subscription,
              output: output,
              timer: timer,
            ));
          });
        } else {
          throw Exception('Could not access storage directory');
        }
      } catch (e) {
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

  void _cancelDownload(int index) {
    var task = _downloadTasks[index];
    task.subscription?.cancel();
    task.output?.close();
    task.timer?.cancel();
    setState(() {
      _downloadTasks.removeAt(index);
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Download canceled')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              decoration: BoxDecoration(
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
                            ? const Color(0xFF58C2FF)
                            : Colors.grey[300],
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(10),
                          bottomLeft: Radius.circular(10),
                        ),
                      ),
                      child: Text(
                        "MP4",
                        style: TextStyle(
                          color: _selectedFormat == 'MP4'
                              ? Colors.white
                              : Colors.grey[800],
                        ),
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
                            ? const Color(0xFF58C2FF)
                            : Colors.grey[300],
                        borderRadius: const BorderRadius.only(
                          topRight: Radius.circular(10),
                          bottomRight: Radius.circular(10),
                        ),
                      ),
                      child: Text(
                        "MP3",
                        style: TextStyle(
                          color: _selectedFormat == 'MP3'
                              ? Colors.white
                              : Colors.grey[800],
                        ),
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
              onTap: _isDownloadInProgress
                  ? null
                  : () => _downloadVideo(_controller.text),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: _isDownloadInProgress
                      ? Colors.grey
                      : const Color(0xFF58C2FF),
                  borderRadius: const BorderRadius.all(Radius.circular(10)),
                ),
                width: MediaQuery.of(context).size.width,
                child: Text(
                  _isDownloadInProgress ? "Downloading..." : "Download",
                  style: const TextStyle(color: Colors.white),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
            const SizedBox(
              height: 10,
            ),
            Expanded(
              child: ListView.builder(
                  physics: const BouncingScrollPhysics(),
                  itemCount: _downloadTasks.length,
                  itemBuilder: (context, index) {
                    var task = _downloadTasks[index];
                    return Row(
                      children: [
                        if (task.thumbnailUrl != null)
                          SizedBox(
                              width: 80,
                              height: 60,
                              child: Image.network(task.thumbnailUrl!))
                        else
                          const SizedBox.shrink(),
                        const SizedBox(
                          width: 10,
                        ),
                        Expanded(
                          // Add this Expanded widget
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  SizedBox(
                                    width: 200,
                                    child: Text(
                                      maxLines: 1,
                                      task.videoTitle,
                                      style: const TextStyle(
                                        overflow: TextOverflow.ellipsis,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                      ),
                                      textAlign: TextAlign.left,
                                    ),
                                  ),
                                  task.isDownloading
                                      ? GestureDetector(
                                          onTap: () => _cancelDownload(index),
                                          child: const Icon(
                                            Icons.cancel,
                                            color: Colors.red,
                                          ))
                                      : const Icon(
                                          Icons.task,
                                          color: Colors.greenAccent,
                                        ),
                                ],
                              ),
                              const SizedBox(height: 5),
                              LinearProgressIndicator(
                                  minHeight: 7,
                                  borderRadius: BorderRadius.circular(10),
                                  value: task.progress,
                                  backgroundColor: Colors.grey[300],
                                  color: const Color(0xFF58C2FF)),
                              const SizedBox(height: 10),
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                      '${task.downloadedMB.toStringAsFixed(2)}MB / ${task.totalSizeMB.toStringAsFixed(2)}MB'),
                                  Text(
                                      '${task.downloadSpeed.toStringAsFixed(2)} MB/s'),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    );
                  }),
            )
          ],
        ),
      ),
    );
  }
}

class _DownloadTask {
  String url;
  String selectedFormat;
  bool isDownloading;
  double progress;
  double downloadedMB;
  double totalSizeMB;
  double downloadSpeed;
  String videoTitle;
  String? thumbnailUrl;
  StreamSubscription<List<int>>? subscription;
  IOSink? output;
  Timer? timer;

  _DownloadTask({
    required this.url,
    required this.selectedFormat,
    this.isDownloading = false,
    this.progress = 0.0,
    this.downloadedMB = 0.0,
    this.totalSizeMB = 0.0,
    this.downloadSpeed = 0.0,
    this.videoTitle = '',
    this.thumbnailUrl,
    this.subscription,
    this.output,
    this.timer,
  });
}
