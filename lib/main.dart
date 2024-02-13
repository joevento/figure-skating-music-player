import 'dart:io';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:file_picker/file_picker.dart';

void main() {
  runApp(const AudioPlayerApp());
}

class AudioPlayerApp extends StatelessWidget {
  const AudioPlayerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      title: 'Figure Skating Audio Player',
      home: AudioPlayerScreen(),
    );
  }
}

class AudioPlayerScreen extends StatefulWidget {
  const AudioPlayerScreen({super.key});

  @override
  _AudioPlayerScreenState createState() => _AudioPlayerScreenState();
}

class _AudioPlayerScreenState extends State<AudioPlayerScreen> {
  late AudioPlayer _audioPlayer;
  late PlayerState _audioPlayerState;
  Duration _duration = const Duration();
  Duration _position = const Duration();
  Duration _resumePosition = const Duration();
  Duration _lastPosition = const Duration();
  String _currentFilePath = "";
  int _presetTime = 0;

  // Global variables to store file paths
  late String _shortProgramFilePath;
  late String _freeProgramFilePath;
  bool _isShortProgramLoaded = false;
  bool _isFreeProgramLoaded = false;

  String formatTime(int seconds) {
    return '${(Duration(seconds: seconds))}'.split('.')[0].padLeft(8, '0');
  }

  Future<String> get _localPath async {
    final directory = await getApplicationDocumentsDirectory();
    return directory.path;
  }

  Future<File> _localFile(String presetFileName) async {
    final path = await _localPath;
    return File('$path/$presetFileName');
  }

  @override
  void initState() {
    super.initState();
    _audioPlayer = AudioPlayer();
    _audioPlayerState = PlayerState.stopped;
    _resumePosition = const Duration();
    _audioPlayer.onPlayerStateChanged.listen((state) {
      setState(() {
        _audioPlayerState = state;
      });
    });

    _audioPlayer.onDurationChanged.listen((newDuration) {
      setState(() {
        _duration = newDuration;
      });
    });

    _audioPlayer.onPositionChanged.listen((newPosition) {
      setState(() {
        _position = newPosition;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Figure Skating Audio Player'),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ElevatedButton(
              onPressed: () => _loadShortProgramMusic(),
              child: const Text('Load Short Program'),
            ),
            const SizedBox(width: 10),
            Checkbox(
              value: _isShortProgramLoaded,
              onChanged: null,
            ),
            ElevatedButton(
              onPressed: () => _loadFreeProgramMusic(),
              child: const Text('Load Free Program'),
            ),
            const SizedBox(width: 10),
            Checkbox(
              value: _isFreeProgramLoaded,
              onChanged: null,
            ),
            ElevatedButton(
              onPressed: () => _onShortButtonClick(),
              child: const Text('Short program'),
            ),
            ElevatedButton(
              onPressed: () => _onLongButtonClick(),
              child: const Text('Free program'),
            ),
            Text(_currentFilePath),
            Slider(
              value: _position.inMilliseconds.toDouble(),
              onChanged: (value) {
                setState(() {
                  _lastPosition = Duration(milliseconds: value.toInt());
                  _audioPlayer.seek(Duration(milliseconds: value.toInt()));
                });
              },
              min: 0.0,
              max: _duration.inMilliseconds.toDouble(),
            ),
            Container(
              padding: const EdgeInsets.all(20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(formatTime(_position.inSeconds)),
                  Text(formatTime((_duration - _position).inSeconds)),
                ],
              ),
            ),
            const SizedBox(height: 5),
            Column(
              children: [
                ElevatedButton(
                  onPressed: () => _onStopButtonClick(),
                  child: const Text('Pause'),
                ),
              ],
            ),
            Column(
              children: [
                ElevatedButton(
                  onPressed: () => _onResumeButtonClick(),
                  child: const Text('Resume'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _playAudio(String path, int startTime) async {
    try {
      var urlSource = DeviceFileSource(path);
      await _audioPlayer.stop();
      await _audioPlayer.play(
        urlSource,
        position: Duration(seconds: startTime),
      );

      _audioPlayer.onDurationChanged.listen((duration) {
        setState(() {
          _duration = const Duration();
        });
      });

      if (_duration.inSeconds <= startTime) {
        _position = Duration.zero;
      } else {
        _position = Duration(seconds: startTime);
      }

      Future.delayed(const Duration(milliseconds: 100), () {
        setState(() {
          _audioPlayerState = PlayerState.playing;
          _currentFilePath = path;
          _presetTime = startTime;
          _resumePosition = const Duration();
          _lastPosition = const Duration();
        });
      });
    } catch (e) {
      print("Error playing audio: $e");
    }
  }

  void _onStopButtonClick() {
    _audioPlayer.stop();
    setState(() {
      _audioPlayerState = PlayerState.stopped;
      _lastPosition = _position;
      _position = const Duration();
    });
  }

  void _onShortButtonClick() {
    _showButtons("preset_short.txt", _shortProgramFilePath, "preset_short.txt");
  }

  void _onLongButtonClick() {
    _showButtons("preset_long.txt", _freeProgramFilePath, "preset_long.txt");
  }

  void _showButtons(String presetFileName, String audioFilePath, String presetFilePath) async {
    List<int> presets = await _readPresets(presetFileName);

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Start time'),
          content: Column(
            children: [
              ElevatedButton(
                onPressed: () => _onFullButtonClick(audioFilePath),
                child: const Text('Full duration'),
              ),
              ..._loadPresets(presets, audioFilePath, presetFileName),
              const SizedBox(height: 15),
              ElevatedButton(
                onPressed: () => _onEditAllButtonClick(presets, audioFilePath, presetFilePath),
                child: const Text('Edit Presets'),
              ),
            ],
          ),
        );
      },
    );
  }

  List<Widget> _loadPresets(List<int> presets, String audioFilePath, String presetFileName) {
    List<Widget> buttons = [];

    for (int i = 0; i < presets.length; i++) {
      buttons.add(
        ElevatedButton(
          onPressed: () {
            _onPresetButtonClick(presets[i], audioFilePath);
          },
          child: Text('Preset ${i + 1}'),
        ),
      );
    }
    ElevatedButton(
      onPressed: () => _onEditAllButtonClick(presets, audioFilePath, presetFileName),
      child: const Text('Edit Presets'),
    );

    return buttons;
  }

  Future<String> _readFile(String filePath) async {
    return await rootBundle.loadString(filePath);
  }

  Future<List<int>> _readPresets(String presetFileName) async {
    try {
      final file = await _localFile(presetFileName);

      if (!await file.exists()) {
        // If the preset file doesn't exist, create it with default values
        await _createDefaultPresetFile(file);
        return [];
      }

      String content = await file.readAsString();

      List<String> lines = content.split('\n');
      List<int> presets = [];

      for (int i = 0; lines.isNotEmpty && i < lines.length; i++) {
        String line = lines[i].trim();

        if (line.isNotEmpty) {
          try {
            int value = int.parse(line);
            presets.add(value);
          } catch (e) {
            print("Error parsing preset value at line $i: '$line'");
          }
        }
      }

      return presets;
    } catch (e) {
      print("Error reading preset file: $e");
      return [];
    }
  }

  Future<void> _createDefaultPresetFile(File file) async {
    // Create the preset file with default values (e.g., 0 seconds)
    await file.writeAsString("10\n20\n30\n40\n50\n60\n70\n80\n90\n");
  }

  void _onPresetButtonClick(int startTime, String audioFilePath) {
    Navigator.pop(context);
    _playAudio(audioFilePath, startTime);
  }

  void _onFullButtonClick(String audioFilePath) {
    Navigator.pop(context);
    _playAudio(audioFilePath, 0);
  }

  void _onEditButtonClick(int startTime, String audioFilePath, String presetFilePath) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => EditPresetScreen(
          filePath: presetFilePath,
        ),
      ),
    );
  }

  void _onEditAllButtonClick(List<int> presets, String audioFilePath, String presetFilePath) {
    Navigator.pop(context);
    _openEditScreenForAllPresets(presets, audioFilePath, presetFilePath);
  }

  void _openEditScreenForAllPresets(List<int> presets, String audioFilePath, String presetFilePath) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => EditPresetScreen(
          filePath: presetFilePath,
        ),
      ),
    );
  }

  void _onResumeButtonClick() {
    _playAudio(_currentFilePath, _lastPosition.inSeconds);
  }

  void _loadShortProgramMusic() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.audio,
      allowMultiple: false,
    );

    if (result != null && result.files.isNotEmpty) {
      _shortProgramFilePath = result.files.first.path!;
      setState(() {
        _isShortProgramLoaded = true;
      });
    }
  }

  void _loadFreeProgramMusic() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.audio,
      allowMultiple: false,
    );

    if (result != null && result.files.isNotEmpty) {
      _freeProgramFilePath = result.files.first.path!;
      setState(() {
        _isFreeProgramLoaded = true;
      });
    }
  }
}

class EditPresetScreen extends StatefulWidget {
  final String filePath;

  const EditPresetScreen({super.key, required this.filePath});

  @override
  _EditPresetScreenState createState() => _EditPresetScreenState();
}

class _EditPresetScreenState extends State<EditPresetScreen> {
  final TextEditingController _controller = TextEditingController();

  Future<File> _localFile() async {
    final path = await _localPath;
    return File('$path/${widget.filePath}');
  }

  Future<String> get _localPath async {
    final directory = await getApplicationDocumentsDirectory();

    return directory.path;
  }

  @override
  void initState() {
    super.initState();
    _loadFile();
  }

  Future<void> _loadFile() async {
    try {
      final file = await _localFile();
      String content = await file.readAsString();
      setState(() {
        _controller.text = content;
      });
    } catch (e) {
      print("Error loading file: $e");
    }
  }

  Future<void> _saveFile() async {
    try {
      final file = await _localFile();
      await file.writeAsString(_controller.text);
    } catch (e) {
      print("Error saving file: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Preset'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Expanded(
              child: TextField(
                controller: _controller,
                maxLines: null,
                expands: true,
              ),
            ),
            ElevatedButton(
              onPressed: () => _saveFile(),
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }
}
