# Video/Audio Downloader App

## Overview

This project is a Flutter application that allows users to download YouTube videos in either MP4 (video) or MP3 (audio) format. The app uses the `youtube_explode_dart` package to fetch video and audio streams and provides a user-friendly interface for managing download tasks. Additionally, the app features notification support to inform users about the progress and completion of their downloads.

## Features

1. **YouTube Video/Audio Downloading**: 
   - Supports downloading videos in MP4 format.
   - Supports downloading audio in MP3 format.

2. **Notification Support**:
   - Notifications for ongoing downloads.
   - Notifications for completed downloads.

3. **Download Management**:
   - List of new download tasks.
   - List of previously downloaded videos.
   - List of previously downloaded audios.

4. **Thumbnail Preview**: 
   - Displays video thumbnails for downloaded videos.

5. **File Management**: 
   - Saves downloaded files in a specific directory on the device.

## Dependencies

- `flutter_local_notifications`: For displaying notifications.
- `path`: For manipulating file paths.
- `path_provider`: For accessing device directories.
- `permission_handler`: For requesting storage permissions.
- `video_thumbnail`: For generating video thumbnails.
- `youtube_explode_dart`: For interacting with YouTube's API.


## Directory Structure

- `lib/`
  - `main.dart`: The main entry point of the application.
  - `widgets/`: Contains custom widgets used in the app.
  - `models/`: Contains model classes used in the app.

## Usage

1. **Enter YouTube URL**: Enter a valid YouTube video URL in the text field provided on the main screen.
2. **Select Format**: Choose either MP4 or MP3 format.
3. **Start Download**: Click the "Download" button to start the download. The app will show a notification indicating the download progress.
4. **Manage Downloads**: 
   - The "New Tasks" tab shows the current download tasks.
   - The "Videos" tab shows previously downloaded videos.
   - The "Audios" tab shows previously downloaded audios.

## Code Explanation

### Home Page
The home page (`MyHomePage`) manages the state of the application, including the list of download tasks and the current selected format. It also handles user interactions such as starting a new download and switching between tabs.

### Download Management
The `_downloadVideo` method handles the download process, including fetching the video stream, saving it to a file, updating the UI with progress information, and showing notifications.

### Notifications
The app uses the `flutter_local_notifications` package to show notifications for ongoing and completed downloads.
