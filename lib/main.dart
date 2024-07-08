import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:path/path.dart' as path;
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:video_thumbnail/video_thumbnail.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';

final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeNotifications();
  runApp(const MyApp());
}

Future<void> initializeNotifications() async {
  const AndroidInitializationSettings initializationSettingsAndroid =
      AndroidInitializationSettings('@mipmap/ic_launcher');
  const InitializationSettings initializationSettings =
      InitializationSettings(android: initializationSettingsAndroid);
  await flutterLocalNotificationsPlugin.initialize(initializationSettings);
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Video downloader',
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
  final List<_DownloadTask> _newTasks = [];
  final List<_DownloadTask> _oldVideos = [];
  final List<_DownloadTask> _oldAudios = [];
  String _selectedTab = 'New Tasks';

  bool _isDownloadInProgress = false;

  Future<void> showNotification(String title) async {
    const AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails(
      'audioId',
      'AudioName',
      importance: Importance.low,
      priority: Priority.high,
      showWhen: false,
      vibrationPattern: null, // Remove vibrations
      enableVibration: false, // Ensure vibration is disabled
      ongoing: true, // Make notification non-dismissible
    );
    const NotificationDetails platformChannelSpecifics =
        NotificationDetails(android: androidPlatformChannelSpecifics);

    await flutterLocalNotificationsPlugin.show(
      0,
      'Now Downloading ❕',
      title,
      platformChannelSpecifics,
      payload: 'item x',
    );
  }

  Future<void> showDoneNotification(String title) async {
    const AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails(
      'audioId',
      'AudioName',
      importance: Importance.high,
      priority: Priority.high,
      showWhen: false,
    );
    const NotificationDetails platformChannelSpecifics =
        NotificationDetails(android: androidPlatformChannelSpecifics);

    await flutterLocalNotificationsPlugin.show(
      0,
      'Finished downloading ✔️',
      title,
      platformChannelSpecifics,
      payload: 'item x',
    );
  }

  void cancelNotification() async {
    await flutterLocalNotificationsPlugin.cancel(0);
  }

  Future<void> _loadExistingFiles() async {
    final directory = Directory('/storage/emulated/0/ytbinstaDownloader');
    if (await directory.exists()) {
      final files = directory.listSync();
      for (var file in files) {
        if (file is File) {
          final fileName = path.basename(file.path);
          final fileExtension = path.extension(file.path).toLowerCase();
          final fileSize = await file.length();
          final fileSizeMB = fileSize / (1024 * 1024);

          Uint8List? thumbnailData;
          if (fileExtension == '.mp4') {
            thumbnailData = await VideoThumbnail.thumbnailData(
              video: file.path,
              imageFormat: ImageFormat.JPEG,
              maxWidth: 128,
              quality: 25,
            );
          }

          final task = _DownloadTask(
            url: '', // We don't have the original URL
            selectedFormat: fileExtension == '.mp3' ? 'MP3' : 'MP4',
            isDownloading: false,
            progress: 1.0,
            downloadedMB: fileSizeMB,
            totalSizeMB: fileSizeMB,
            downloadSpeed: 0.0,
            videoTitle: path.basenameWithoutExtension(fileName),
            thumbnailData: thumbnailData,
          );

          setState(() {
            if (fileExtension == '.mp4') {
              _oldVideos.insert(0, task);
            } else if (fileExtension == '.mp3') {
              _oldAudios.insert(0, task);
            }
          });
        }
      }
    }
  }

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
              _newTasks.first.progress = progress;
              _newTasks.first.downloadedMB =
                  downloadedBytes / (1024 * 1024); // Convert to MB
              _newTasks.first.downloadSpeed = downloadSpeed;
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
                _newTasks.first.downloadedMB = _newTasks.first.totalSizeMB;
                _newTasks.first.isDownloading = false;
                _newTasks.first.progress = 1.0; // Ensure progress reaches 100%
                _isDownloadInProgress = false; // Reset the flag
              });

              cancelNotification();
              showDoneNotification(videoTitle);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                    content: Text(
                        '${_selectedFormat.toUpperCase()} saved to $savePath')),
              );
            },
            onError: (e) {
              setState(() {
                _newTasks.first.isDownloading = false;
                _isDownloadInProgress = false; // Reset the flag
              });
              cancelNotification();
              timer.cancel();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Error: ${e.toString()}')),
              );
            },
            cancelOnError: true,
          );

          setState(() {
            _newTasks.insert(
              0, // Insert at the beginning of the list
              _DownloadTask(
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
              ),
            );
            showNotification(videoTitle);
          });
        } else {
          setState(() {
            _isDownloadInProgress = false;
          });
          cancelNotification();
          throw Exception('Could not access storage directory');
        }
      } catch (e) {
        setState(() {
          _isDownloadInProgress = false;
        });
        cancelNotification();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${e.toString()}')),
        );
      }
    } else {
      setState(() {
        _isDownloadInProgress = false;
      });
      cancelNotification();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Storage permission denied')),
      );
    }
  }

  void _cancelDownload(int index) {
    var task = _newTasks[index];
    task.subscription?.cancel();
    task.output?.close();
    task.timer?.cancel();
    setState(() {
      _newTasks.removeAt(index);
      _isDownloadInProgress = false;
    });
    cancelNotification();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Download canceled')),
    );
  }

  @override
  void initState() {
    // TODO: implement initState
    super.initState();
    _loadExistingFiles();
  }

  @override
  void dispose() {
    cancelNotification(); // Cancel the notification when app is disposed

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
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
                    hintText: "Enter a youtube link/url",
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
                        padding: const EdgeInsets.all(10),
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
                        padding: const EdgeInsets.all(10),
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
              const SizedBox(height: 20),
              TaskTabs(
                selectedTab: _selectedTab,
                onTabSelected: (tab) {
                  setState(() {
                    _selectedTab = tab;
                  });
                },
              ),
              const SizedBox(height: 10),
              Expanded(
                child: _buildSelectedTaskList(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSelectedTaskList() {
    switch (_selectedTab) {
      case 'New Tasks':
        return _buildTaskList(_newTasks, true);
      case 'Videos':
        return _buildTaskList(_oldVideos, false);
      case 'Audios':
        return _buildTaskList(_oldAudios, false);
      default:
        return Container();
    }
  }

  Widget _buildTaskList(List<_DownloadTask> tasks, bool isNewTask) {
    if (tasks.isNotEmpty) {
      return ListView.builder(
        physics: const BouncingScrollPhysics(),
        itemCount: tasks.length,
        itemBuilder: (context, index) {
          var task = tasks[index];
          return Row(
            children: [
              if (task.thumbnailData != null)
                SizedBox(
                  width: 80,
                  height: 60,
                  child: Image.memory(task.thumbnailData!),
                )
              else if (task.thumbnailUrl != null)
                SizedBox(
                  width: 80,
                  height: 60,
                  child: Image.network(task.thumbnailUrl!),
                )
              else
                SizedBox(
                  width: 80,
                  height: 60,
                  child: Icon(
                    task.selectedFormat == 'MP3'
                        ? Icons.audio_file_rounded
                        : Icons.video_file_rounded,
                    color: const Color(0xFF58C2FF),
                    size: 20,
                  ),
                ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        SizedBox(
                          width: 200,
                          child: Text(
                            task.videoTitle,
                            maxLines: 1,
                            style: const TextStyle(
                              overflow: TextOverflow.ellipsis,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                            textAlign: TextAlign.left,
                          ),
                        ),
                        if (isNewTask && task.isDownloading)
                          GestureDetector(
                            onTap: () => _cancelDownload(index),
                            child: const Icon(
                              Icons.cancel,
                              color: Colors.red,
                            ),
                          )
                        else
                          const Icon(
                            Icons.check_circle,
                            color: Colors.greenAccent,
                            size: 18,
                          ),
                      ],
                    ),
                    const SizedBox(height: 5),
                    LinearProgressIndicator(
                      borderRadius: BorderRadius.circular(10),
                      minHeight: 7,
                      value: task.progress,
                      backgroundColor: Colors.grey[300],
                      color: const Color(0xFF58C2FF),
                    ),
                    const SizedBox(height: 5),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '${task.downloadedMB.toStringAsFixed(2)}MB / ${task.totalSizeMB.toStringAsFixed(2)}MB',
                        ),
                        Text('${task.downloadSpeed.toStringAsFixed(2)} MB/s'),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      );
    } else {
      return const Text(
        "No tasks to show!",
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: 18,
        ),
      );
    }
  }
}

class TaskTabs extends StatelessWidget {
  final String selectedTab;
  final Function(String) onTabSelected;

  const TaskTabs({
    Key? key,
    required this.selectedTab,
    required this.onTabSelected,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _buildTab('New Tasks'),
        _buildTab('Videos'),
        _buildTab('Audios'),
      ],
    );
  }

  Widget _buildTab(String tabName) {
    return GestureDetector(
      onTap: () => onTabSelected(tabName),
      child: Text(
        tabName,
        style: TextStyle(
          fontSize: 16,
          fontWeight:
              selectedTab == tabName ? FontWeight.bold : FontWeight.normal,
          color:
              selectedTab == tabName ? const Color(0xFF58C2FF) : Colors.black,
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
  Uint8List? thumbnailData;
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
    this.thumbnailData,
    this.subscription,
    this.output,
    this.timer,
  });
}
