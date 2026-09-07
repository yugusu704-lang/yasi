import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';
import '../models/listening_test_info.dart';

class AudioPlayerService {
  final AudioPlayer _player = AudioPlayer();
  ListeningTestInfo? _currentTest;
  int _currentSentenceIndex = 0;
  bool _isSingleLoop = false;
  VoidCallback? onPlayStarted;
  Function(int seconds)? onListeningTimeAccumulated;
  VoidCallback? onSentenceRepeated;
  Timer? _listeningTickTimer;

  final StreamController<int> _sentenceIndexController =
      StreamController<int>.broadcast();
  final StreamController<bool> _singleLoopController =
      StreamController<bool>.broadcast();

  Stream<int> get currentSentenceIndexStream => _sentenceIndexController.stream;
  Stream<bool> get isSingleLoopStream => _singleLoopController.stream;
  Stream<Duration> get positionStream => _player.positionStream;
  Stream<PlayerState> get playerStateStream => _player.playerStateStream;
  Stream<double> get speedStream => _player.speedStream;

  AudioPlayer get player => _player;
  ListeningTestInfo? get currentTest => _currentTest;
  int get currentSentenceIndex => _currentSentenceIndex;
  bool get isSingleLoop => _isSingleLoop;
  double get currentSpeed => _player.speed;
  bool get isPlaying => _player.playing;

  StreamSubscription? _positionSub;

  AudioPlayerService() {
    _positionSub = _player.positionStream.listen(_onPositionUpdate);
  }

  Future<void> loadTest(ListeningTestInfo test) async {
    _currentTest = test;
    _currentSentenceIndex = 0;
    _sentenceIndexController.add(0);

    try {
      // 优先从本地 assets 离线加载
      if (test.localAudioPath.isNotEmpty) {
        try {
          await _player.setAsset(test.localAudioPath);
          return;
        } catch (_) {
          // 本地资产加载失败时降级尝试网络源
        }
      }

      if (test.audioUrl.isNotEmpty) {
        await _player.setUrl(test.audioUrl);
      }
    } catch (e) {
      // 捕获网络错误，不影响界面操作
    }
  }

  void _onPositionUpdate(Duration pos) {
    if (_currentTest == null || _currentTest!.sentences.isEmpty) return;

    final posMs = pos.inMilliseconds;
    final sentences = _currentTest!.sentences;

    // 单句循环处理
    if (_isSingleLoop && _currentSentenceIndex < sentences.length) {
      final currentS = sentences[_currentSentenceIndex];
      if (posMs >= currentS.endMs) {
        onSentenceRepeated?.call();
        _player.seek(Duration(milliseconds: currentS.startMs));
        return;
      }
    }

    // 自动跟踪当前正在播放的句子
    for (int i = 0; i < sentences.length; i++) {
      if (posMs >= sentences[i].startMs && posMs <= sentences[i].endMs) {
        if (_currentSentenceIndex != i) {
          _currentSentenceIndex = i;
          _sentenceIndexController.add(i);
        }
        break;
      }
    }
  }

  void _startListeningTracker() {
    _listeningTickTimer?.cancel();
    _listeningTickTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (_player.playing) {
        onListeningTimeAccumulated?.call(5);
      }
    });
  }

  void _stopListeningTracker() {
    _listeningTickTimer?.cancel();
    _listeningTickTimer = null;
  }

  Future<void> play() async {
    onPlayStarted?.call();
    _startListeningTracker();
    await _player.play();
  }

  Future<void> pause() async {
    _stopListeningTracker();
    await _player.pause();
  }

  Future<void> togglePlay() async {
    if (_player.playing) {
      await pause();
    } else {
      await play();
    }
  }

  Future<void> seek(Duration position) => _player.seek(position);

  Future<void> setSpeed(double speed) => _player.setSpeed(speed);

  void toggleSingleLoop() {
    _isSingleLoop = !_isSingleLoop;
    _singleLoopController.add(_isSingleLoop);
  }

  Future<void> jumpToSentence(int index) async {
    if (_currentTest == null || _currentTest!.sentences.isEmpty) return;
    if (index < 0 || index >= _currentTest!.sentences.length) return;

    if (index == _currentSentenceIndex) {
      onSentenceRepeated?.call();
    }
    _currentSentenceIndex = index;
    _sentenceIndexController.add(index);
    final targetSentence = _currentTest!.sentences[index];
    await _player.seek(Duration(milliseconds: targetSentence.startMs));
  }

  Future<void> previousSentence() async {
    if (_currentSentenceIndex > 0) {
      onSentenceRepeated?.call();
      await jumpToSentence(_currentSentenceIndex - 1);
    }
  }

  Future<void> nextSentence() async {
    if (_currentTest != null &&
        _currentSentenceIndex < _currentTest!.sentences.length - 1) {
      await jumpToSentence(_currentSentenceIndex + 1);
    }
  }

  Future<void> skipSeconds(int seconds) async {
    final currentPos = _player.position;
    final newPos = currentPos + Duration(seconds: seconds);
    await _player.seek(newPos < Duration.zero ? Duration.zero : newPos);
  }

  void dispose() {
    _stopListeningTracker();
    _positionSub?.cancel();
    _sentenceIndexController.close();
    _singleLoopController.close();
    _player.dispose();
  }
}
