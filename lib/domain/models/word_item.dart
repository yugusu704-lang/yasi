class WordItem {
  final String id;
  final String word;
  final String phoneticUk;
  final String phoneticUs;
  final String definitionZh;
  final String ieltsTag;
  final String contextSentenceEn;
  final String contextSentenceZh;
  final String sourceTest;
  final bool isFavorite;
  final DateTime addedAt;

  const WordItem({
    required this.id,
    required this.word,
    required this.phoneticUk,
    required this.phoneticUs,
    required this.definitionZh,
    this.ieltsTag = '雅思核心',
    this.contextSentenceEn = '',
    this.contextSentenceZh = '',
    this.sourceTest = '',
    this.isFavorite = false,
    required this.addedAt,
  });

  WordItem copyWith({
    String? id,
    String? word,
    String? phoneticUk,
    String? phoneticUs,
    String? definitionZh,
    String? ieltsTag,
    String? contextSentenceEn,
    String? contextSentenceZh,
    String? sourceTest,
    bool? isFavorite,
    DateTime? addedAt,
  }) {
    return WordItem(
      id: id ?? this.id,
      word: word ?? this.word,
      phoneticUk: phoneticUk ?? this.phoneticUk,
      phoneticUs: phoneticUs ?? this.phoneticUs,
      definitionZh: definitionZh ?? this.definitionZh,
      ieltsTag: ieltsTag ?? this.ieltsTag,
      contextSentenceEn: contextSentenceEn ?? this.contextSentenceEn,
      contextSentenceZh: contextSentenceZh ?? this.contextSentenceZh,
      sourceTest: sourceTest ?? this.sourceTest,
      isFavorite: isFavorite ?? this.isFavorite,
      addedAt: addedAt ?? this.addedAt,
    );
  }
}
