import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:just_audio/just_audio.dart';
import 'package:flutter_tts/flutter_tts.dart';

class AudioCacheService {
  final AudioPlayer _audioPlayer = AudioPlayer();
  final FlutterTts _tts = FlutterTts();
  bool _ttsInitialized = false;

  /// 当任何词汇或例句音频开始播放时触发，用于暂停背景听力
  VoidCallback? onAudioPlaybackStarting;

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

  /// 停止当前正在播放的所有词汇与例句音频
  Future<void> stop() async {
    await _audioPlayer.stop();
    await _tts.stop();
  }

  /// 播放真人英音发音（优先本地缓存，若无则从在线高品质词典MP3拉取并缓存，离线/无网则优雅降级为本地TTS）
  Future<void> playWordUk(String word) async {
    final cleanWord = word.trim().toLowerCase();
    if (cleanWord.isEmpty) return;

    onAudioPlaybackStarting?.call();

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

  /// 朗读完整雅思真题语境例句（3级弹性容灾架构）
  /// Tier 1: 内置高保真离线资产 (assets/audio/sentences/$word.mp3)
  /// Tier 2: 应用沙盒本地持久化缓存 (sentence_audio/$key.mp3)
  /// Tier 3: 免翻墙高速英音神经网络音频接口 (Baidu UK TTS) 并写入沙盒缓存
  /// Tier 4: 系统 TTS 优雅兜底
  Future<void> speakSentence(String sentence, {String? word}) async {
    final cleanSentence = sentence.trim();
    if (cleanSentence.isEmpty) return;
    final cleanWord = word?.trim().toLowerCase() ?? '';

    onAudioPlaybackStarting?.call();

    // Tier 1: 内置高保真离线资产检查（预置词 100% 毫秒级零延迟响应该级别）
    if (cleanWord.isNotEmpty) {
      final assetPath = 'assets/audio/sentences/$cleanWord.mp3';
      try {
        await _audioPlayer.stop();
        await _audioPlayer.setAsset(assetPath);
        await _audioPlayer.play();
        return;
      } catch (_) {
        // 不在内置 assets 中，继续 Tier 2
      }
    }

    // Tier 2: 沙盒文件缓存检查
    final cacheKey = cleanWord.isNotEmpty
        ? cleanWord
        : cleanSentence.hashCode.abs().toString();
    final cachedFile = await _getCachedSentenceFile(cacheKey);

    if (cachedFile != null &&
        await cachedFile.exists() &&
        (await cachedFile.length()) > 500) {
      try {
        await _audioPlayer.stop();
        await _audioPlayer.setFilePath(cachedFile.path);
        await _audioPlayer.play();
        return;
      } catch (_) {
        // 缓存文件损坏，继续 Tier 3
      }
    }

    // Tier 3: 免翻墙高速英音神经网络音频接口 (Baidu UK TTS) 并写入沙盒缓存
    try {
      final url =
          'https://fanyi.baidu.com/gettts?lan=uk&text=${Uri.encodeComponent(cleanSentence)}&spd=4&source=web';
      final response = await http.get(
        Uri.parse(url),
        headers: {
          'User-Agent':
              'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko)',
        },
      ).timeout(const Duration(seconds: 4));

      if (response.statusCode == 200 && response.bodyBytes.length > 500) {
        if (cachedFile != null) {
          await cachedFile.writeAsBytes(response.bodyBytes);
          await _audioPlayer.stop();
          await _audioPlayer.setFilePath(cachedFile.path);
        } else {
          await _audioPlayer.stop();
          await _audioPlayer.setUrl(url);
        }
        await _audioPlayer.play();
        return;
      }
    } catch (_) {
      // 网络异常或网络超时，降级至 Tier 4
    }

    // Tier 4: 系统离线 TTS 兜底
    try {
      if (!_ttsInitialized) await _initTts();
      await _tts.stop();
      await _tts.speak(cleanSentence);
    } catch (_) {
      // 优雅忽略
    }
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

  Future<File?> _getCachedSentenceFile(String key) async {
    try {
      final docDir = await getApplicationDocumentsDirectory();
      final audioDir = Directory('${docDir.path}/sentence_audio');
      if (!await audioDir.exists()) {
        await audioDir.create(recursive: true);
      }
      final safeKey = key.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');
      return File('${audioDir.path}/$safeKey.mp3');
    } catch (_) {
      return null;
    }
  }

  void dispose() {
    _audioPlayer.dispose();
    _tts.stop();
  }
}
