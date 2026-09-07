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
      testId: json['testId']?.toString() ?? '',
      book: json['book']?.toString() ?? '',
      testNumber: (json['testNumber'] ?? json['testNum']) is int
          ? (json['testNumber'] ?? json['testNum']) as int
          : int.tryParse((json['testNumber'] ?? json['testNum'])?.toString() ?? '1') ?? 1,
      section: (json['section'] ?? json['sectionNum']) is int
          ? (json['section'] ?? json['sectionNum']) as int
          : int.tryParse((json['section'] ?? json['sectionNum'])?.toString() ?? '1') ?? 1,
      title: json['title']?.toString() ?? '',
      audioUrl: json['audioUrl']?.toString() ?? '',
      localAudioPath: json['localAudioPath']?.toString() ?? '',
      totalDurationMs: json['totalDurationMs'] as int? ?? 0,
      sentences: (json['sentences'] as List<dynamic>?)
              ?.map((e) => SubtitleSentence.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      questions: (json['questions'] as List<dynamic>?)
              ?.map((e) {
                final m = e as Map<String, dynamic>;
                final ansRaw = m['acceptableAnswers'] ?? m['acceptable_answers'];
                final List<String> ans = [];
                if (ansRaw is List) {
                  for (final a in ansRaw) {
                    if (a != null) ans.add(a.toString());
                  }
                }
                return ExamQuestion(
                  questionNumber: m['questionNumber'] ?? m['question_number'] ?? 1,
                  promptBefore: m['promptBefore'] ?? m['prompt_before'] ?? '',
                  promptAfter: m['promptAfter'] ?? m['prompt_after'] ?? '',
                  acceptableAnswers: ans,
                  targetSentenceIndex: m['targetSentenceIndex'] ?? m['target_sentence_index'] ?? 0,
                  userAnswer: m['userAnswer'] ?? m['user_answer'] ?? '',
                );
              })
              .toList() ??
          const [],
      isDownloaded: json['isDownloaded'] as bool? ?? true,
      playCount: json['playCount'] as int? ?? 0,
      completionRate: (json['completionRate'] as num?)?.toDouble() ?? 0.0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'testId': testId,
      'book': book,
      'testNumber': testNumber,
      'section': section,
      'title': title,
      'audioUrl': audioUrl,
      'localAudioPath': localAudioPath,
      'totalDurationMs': totalDurationMs,
      'sentences': sentences.map((s) => s.toJson()).toList(),
      'questions': questions
          .map((q) => {
                'questionNumber': q.questionNumber,
                'promptBefore': q.promptBefore,
                'promptAfter': q.promptAfter,
                'acceptableAnswers': q.acceptableAnswers,
                'targetSentenceIndex': q.targetSentenceIndex,
              })
          .toList(),
      'isDownloaded': isDownloaded,
      'playCount': playCount,
      'completionRate': completionRate,
    };
  }
}
