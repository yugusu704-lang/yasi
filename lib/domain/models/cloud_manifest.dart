class ManifestTestEntry {
  final String testId;
  final int book;
  final int testNum;
  final int sectionNum;
  final String title;
  final int audioSize;
  final List<String> audioUrls;
  final String companionJsonUrl;
  final String? sha256;
  final int version;

  const ManifestTestEntry({
    required this.testId,
    required this.book,
    required this.testNum,
    required this.sectionNum,
    required this.title,
    this.audioSize = 0,
    required this.audioUrls,
    required this.companionJsonUrl,
    this.sha256,
    this.version = 1,
  });

  String get preferredAudioUrl =>
      audioUrls.isNotEmpty ? audioUrls.first : '';

  String? get googleDriveFallbackUrl {
    for (final url in audioUrls) {
      if (url.contains('drive.google.com') || url.contains('drive.usercontent.google.com')) {
        return url;
      }
    }
    return null;
  }

  String get formattedSize {
    if (audioSize <= 0) return '0 MB';
    final mb = audioSize / (1024 * 1024);
    return '${mb.toStringAsFixed(1)} MB';
  }

  factory ManifestTestEntry.fromJson(Map<String, dynamic> json) {
    final urlsRaw = json['audioUrls'] ?? json['audio_urls'];
    final List<String> urls = [];
    if (urlsRaw is List) {
      for (final u in urlsRaw) {
        if (u != null) urls.add(u.toString());
      }
    } else if (json['audio_url'] != null) {
      urls.add(json['audio_url'].toString());
    }

    return ManifestTestEntry(
      testId: json['testId'] ?? json['test_id'] ?? '',
      book: json['book'] is int ? json['book'] : int.tryParse('${json['book']}') ?? 0,
      testNum: json['testNum'] ?? json['test_num'] ?? 1,
      sectionNum: json['sectionNum'] ?? json['section_num'] ?? 1,
      title: json['title'] ?? '',
      audioSize: json['audioSize'] ?? json['audio_size'] ?? 0,
      audioUrls: urls,
      companionJsonUrl: json['companionJsonUrl'] ?? json['companion_json_url'] ?? json['json_url'] ?? '',
      sha256: json['sha256'],
      version: json['version'] ?? 1,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'testId': testId,
      'book': book,
      'testNum': testNum,
      'sectionNum': sectionNum,
      'title': title,
      'audioSize': audioSize,
      'audioUrls': audioUrls,
      'companionJsonUrl': companionJsonUrl,
      if (sha256 != null) 'sha256': sha256,
      'version': version,
    };
  }
}

class CloudManifest {
  final int version;
  final String lastUpdated;
  final List<ManifestTestEntry> tests;

  const CloudManifest({
    required this.version,
    required this.lastUpdated,
    required this.tests,
  });

  factory CloudManifest.fromJson(Map<String, dynamic> json) {
    final testsList = json['tests'] as List<dynamic>? ?? [];
    return CloudManifest(
      version: json['version'] as int? ?? 1,
      lastUpdated: json['lastUpdated'] ?? json['last_updated'] ?? '',
      tests: testsList
          .map((item) => ManifestTestEntry.fromJson(item as Map<String, dynamic>))
          .toList(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'version': version,
      'lastUpdated': lastUpdated,
      'tests': tests.map((t) => t.toJson()).toList(),
    };
  }
}
