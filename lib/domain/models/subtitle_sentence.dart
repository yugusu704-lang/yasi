class SubtitleSentence {
  final int index;
  final int startMs;
  final int endMs;
  final String textEn;
  final String textZh;
  final List<String> keyWords;

  const SubtitleSentence({
    required this.index,
    required this.startMs,
    required this.endMs,
    required this.textEn,
    required this.textZh,
    this.keyWords = const [],
  });

  factory SubtitleSentence.fromJson(Map<String, dynamic> json) {
    return SubtitleSentence(
      index: json['index'] as int? ?? 0,
      startMs: json['startMs'] as int? ?? 0,
      endMs: json['endMs'] as int? ?? 0,
      textEn: json['textEn'] as String? ?? '',
      textZh: json['textZh'] as String? ?? '',
      keyWords: (json['keyWords'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
    );
  }

  Map<String, dynamic> toJson() => {
        'index': index,
        'startMs': startMs,
        'endMs': endMs,
        'textEn': textEn,
        'textZh': textZh,
        'keyWords': keyWords,
      };

  bool containsTimestamp(int timestampMs) {
    return timestampMs >= startMs && timestampMs <= endMs;
  }
}
