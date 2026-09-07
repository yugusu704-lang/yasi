import 'subtitle_sentence.dart';
import 'exam_question.dart';

class ListeningTestInfo {
  final String testId;
  final String book;
  final int testNumber;
  final int section;
  final String title;
  final String audioUrl;
  final String localAudioPath;
  final int totalDurationMs;
  final List<SubtitleSentence> sentences;
  final List<ExamQuestion> questions;
  final bool isDownloaded;
  final int playCount;
  final double completionRate;

  const ListeningTestInfo({
    required this.testId,
    required this.book,
    required this.testNumber,
    required this.section,
    required this.title,
    required this.audioUrl,
    required this.localAudioPath,
    required this.totalDurationMs,
    required this.sentences,
    this.questions = const [],
    this.isDownloaded = true,
    this.playCount = 0,
    this.completionRate = 0.0,
  });

  String get displayTag => '$book Test $testNumber Section $section';

  factory ListeningTestInfo.fromJson(Map<String, dynamic> json) {
    return ListeningTestInfo(
      testId: json['testId'] as String? ?? '',
      book: json['book'] as String? ?? '',
      testNumber: json['testNumber'] as int? ?? 1,
      section: json['section'] as int? ?? 1,
      title: json['title'] as String? ?? '',
      audioUrl: json['audioUrl'] as String? ?? '',
      localAudioPath: json['localAudioPath'] as String? ?? '',
      totalDurationMs: json['totalDurationMs'] as int? ?? 0,
      sentences: (json['sentences'] as List<dynamic>?)
              ?.map((e) => SubtitleSentence.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      questions: const [],
      isDownloaded: json['isDownloaded'] as bool? ?? true,
      playCount: json['playCount'] as int? ?? 0,
      completionRate: (json['completionRate'] as num?)?.toDouble() ?? 0.0,
    );
  }
}
