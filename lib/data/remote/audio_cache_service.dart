import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:just_audio/just_audio.dart';
import 'package:flutter_tts/flutter_tts.dart';

class AudioCacheService {
  final AudioPlayer _audioPlayer = AudioPlayer();
  final FlutterTts _tts = FlutterTts();
  bool _ttsInitialized = false;

  AudioCacheService() {
    _initTts();
  }

  Future<void> _initTts() async {
    try {
      await _tts.setLanguage('en-GB');
      await _tts.setSpeechRate(0.45);
      _ttsInitialized = true;
    } catch (_) {}
  }

  /// 播放真人英音发音（优先本地缓存，若无则从在线高品质词典MP3拉取并缓存，离线/无网则优雅降级为本地TTS）
  Future<void> playWordUk(String word) async {
    final cleanWord = word.trim().toLowerCase();
    if (cleanWord.isEmpty) return;

    try {
      final file = await _getCachedAudioFile(cleanWord);
      if (file != null && await file.exists() && (await file.length()) > 500) {
        await _audioPlayer.stop();
        await _audioPlayer.setFilePath(file.path);
        await _audioPlayer.play();
        return;
      }

      // 从真人英音发音源抓取 (type=1 为标准英音 Received Pronunciation)
      final url =
          'https://dict.youdao.com/dictvoice?audio=${Uri.encodeComponent(cleanWord)}&type=1';
      final response =
          await http.get(Uri.parse(url)).timeout(const Duration(seconds: 4));

      if (response.statusCode == 200 && response.bodyBytes.length > 500) {
        if (file != null) {
          await file.writeAsBytes(response.bodyBytes);
          await _audioPlayer.stop();
          await _audioPlayer.setFilePath(file.path);
        } else {
          await _audioPlayer.stop();
          await _audioPlayer.setUrl(url);
        }
        await _audioPlayer.play();
        return;
      }
    } catch (_) {
      // 网络异常或音频解码异常，自动降级至系统 TTS
    }

    // 离线降级方案：本地离线英音 TTS
    if (!_ttsInitialized) await _initTts();
    await _tts.stop();
    await _tts.speak(cleanWord);
  }

  /// 朗读完整雅思真题语境例句（TTS 纯正英音）
  Future<void> speakSentence(String sentence) async {
    if (!_ttsInitialized) await _initTts();
    await _tts.stop();
    await _tts.speak(sentence);
  }

  Future<File?> _getCachedAudioFile(String word) async {
    try {
      final docDir = await getApplicationDocumentsDirectory();
      final audioDir = Directory('${docDir.path}/word_audio');
      if (!await audioDir.exists()) {
        await audioDir.create(recursive: true);
      }
      return File('${audioDir.path}/$word.mp3');
    } catch (_) {
      return null;
    }
  }

  void dispose() {
    _audioPlayer.dispose();
    _tts.stop();
  }
}
